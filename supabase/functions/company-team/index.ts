import { createClient } from 'supabase';

const cors = (origin: string) => ({
  'Access-Control-Allow-Origin': origin,
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Vary': 'Origin',
});

const json = (body: unknown, status = 200, origin = 'https://talentos-industrial.vercel.app') =>
  new Response(JSON.stringify(body), { status, headers: { ...cors(origin), 'Content-Type': 'application/json' } });

const normalizeEmail = (value: unknown) => String(value ?? '').trim().toLowerCase();
const isUuid = (value: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
const normalizeCnpj = (value: unknown) => String(value ?? '').replace(/\D/g, '');
const isValidCnpj = (value: string) => {
  if (!/^\d{14}$/.test(value) || /^(\d)\1{13}$/.test(value)) return false;
  const calc = (digits: string, weights: number[]) => {
    const sum = digits.split('').reduce((total, digit, index) => total + Number(digit) * weights[index], 0);
    const remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  };
  const first = calc(value.slice(0, 12), [5,4,3,2,9,8,7,6,5,4,3,2]);
  const second = calc(value.slice(0, 12) + String(first), [6,5,4,3,2,9,8,7,6,5,4,3,2]);
  return value.endsWith(String(first) + String(second));
};

Deno.serve(async (request) => {
  const appUrl = Deno.env.get('APP_URL') ?? 'https://talentos-industrial.vercel.app';
  const appOrigin = new URL(appUrl).origin;
  const requestOrigin = request.headers.get('Origin') ?? '';
  const origin = requestOrigin === appOrigin || requestOrigin === 'http://localhost:5173' ? requestOrigin : appOrigin;
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors(origin) });
  if (request.method !== 'POST') return json({ error: 'Método não permitido.' }, 405, origin);

  const authorization = request.headers.get('Authorization') ?? '';
  const token = authorization.replace(/^Bearer\s+/i, '');
  if (!token) return json({ error: 'Autenticação necessária.' }, 401, origin);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceKey) return json({ error: 'Configuração segura do servidor incompleta.' }, 500, origin);

  const callerClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: `Bearer ${token}` } } });
  const admin = createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: callerResult, error: callerError } = await callerClient.auth.getUser(token);
  if (callerError || !callerResult.user) return json({ error: 'Sessão inválida ou expirada.' }, 401, origin);
  const caller = callerResult.user;

  try {
    const body = await request.json();
    const action = String(body.action ?? '');

    if (action === 'create-company') {
      if (!caller.email_confirmed_at) return json({ error: 'Confirme seu e-mail antes de cadastrar a empresa.' }, 403, origin);
      const name = String(body.name ?? '').trim();
      const cnpj = normalizeCnpj(body.cnpj);
      const industry = String(body.industry ?? '').trim();
      const cityLabel = String(body.city ?? '').trim();
      if (!name || name.length > 160) return json({ error: 'Informe o nome da empresa.' }, 400, origin);
      if (!isValidCnpj(cnpj)) return json({ error: 'Informe um CNPJ válido.' }, 400, origin);
      if (industry.length > 120) return json({ error: 'Segmento inválido.' }, 400, origin);
      const cityMatch = cityLabel.match(/^(.+?)\s+—\s+([A-Z]{2})$/);
      if (!cityMatch) return json({ error: 'Selecione uma cidade da lista oficial de municípios.' }, 400, origin);
      const cityName = cityMatch[1].trim();
      const state = cityMatch[2].toUpperCase();
      const { data: city, error: cityError } = await admin
        .from('brazil_cities')
        .select('ibge_code,name,uf')
        .eq('name', cityName)
        .eq('uf', state)
        .maybeSingle();
      if (cityError) throw cityError;
      if (!city) return json({ error: 'Cidade não encontrada na base oficial.' }, 400, origin);

      const { data: company, error } = await admin.rpc('company_team_create_company_service', {
        p_actor_id: caller.id,
        p_name: name,
        p_cnpj: cnpj,
        p_city: `${city.name} — ${String(city.uf).trim()}`,
        p_state: String(city.uf).trim(),
        p_city_ibge_code: city.ibge_code,
        p_industry: industry || null,
      });
      if (error) throw error;
      return json({ company }, 200, origin);
    }

    if (action === 'accept-invitation') {
      const invitationId = String(body.invitationId ?? '');
      if (!isUuid(invitationId)) return json({ error: 'Convite inválido.' }, 400, origin);
      const email = normalizeEmail(caller.email);
      if (!email) return json({ error: 'Sua conta precisa ter um e-mail válido.' }, 400, origin);
      const { error } = await admin.rpc('company_team_accept_invitation_service', {
        p_actor_id: caller.id,
        p_actor_email: email,
        p_invitation_id: invitationId,
      });
      if (error) throw error;
      return json({ ok: true }, 200, origin);
    }

    const companyId = String(body.companyId ?? '');
    if (!isUuid(companyId)) return json({ error: 'Empresa inválida.' }, 400, origin);

    const { data: membership, error: membershipError } = await admin
      .from('company_members').select('member_role').eq('company_id', companyId).eq('user_id', caller.id).maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) return json({ error: 'Você não faz parte desta empresa.' }, 403, origin);
    const isOwner = membership.member_role === 'owner';

    if (action === 'list') {
      const [{ data: members, error: membersError }, { data: invites, error: invitesError }] = await Promise.all([
        admin.from('company_members').select('user_id,member_role,created_at').eq('company_id', companyId).order('created_at'),
        admin.from('company_invitations').select('id,invited_email,member_role,status,created_at,expires_at').eq('company_id', companyId).eq('status', 'pending').order('created_at', { ascending: false }),
      ]);
      if (membersError) throw membersError;
      if (invitesError) throw invitesError;
      const ids = (members ?? []).map((row) => row.user_id);
      const { data: profiles, error: profilesError } = ids.length
        ? await admin.from('profiles').select('id,full_name').in('id', ids)
        : { data: [], error: null };
      if (profilesError) throw profilesError;
      const profilesById = new Map((profiles ?? []).map((profile) => [profile.id, profile]));
      const membersWithEmail = await Promise.all((members ?? []).map(async (member) => {
        const { data } = await admin.auth.admin.getUserById(member.user_id);
        return { userId: member.user_id, fullName: profilesById.get(member.user_id)?.full_name ?? 'Membro da equipe', email: data.user?.email ?? '', role: member.member_role, createdAt: member.created_at };
      }));
      return json({ members: membersWithEmail, invitations: invites ?? [], canManage: isOwner }, 200, origin);
    }

    if (!isOwner) return json({ error: 'Somente a pessoa proprietária pode administrar a equipe.' }, 403, origin);

    if (action === 'invite') {
      const email = normalizeEmail(body.email);
      const role = String(body.memberRole ?? '');
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) return json({ error: 'Informe um e-mail válido.' }, 400, origin);
      if (role !== 'recruiter' && role !== 'viewer') return json({ error: 'Escolha Recruiter ou Viewer.' }, 400, origin);

      const { error: revokeError } = await admin.from('company_invitations').update({ status: 'revoked' }).eq('company_id', companyId).eq('invited_email', email).eq('status', 'pending');
      if (revokeError) throw revokeError;
      const { data: invitation, error: insertError } = await admin.from('company_invitations').insert({ company_id: companyId, invited_email: email, member_role: role, invited_by: caller.id }).select('id,expires_at').single();
      if (insertError) throw insertError;
      const inviteUrl = `${appUrl.replace(/\/$/, '')}/?teamInvite=${encodeURIComponent(invitation.id)}`;
      const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
        redirectTo: inviteUrl,
        data: { full_name: email.split('@')[0] },
      });
      if (!inviteError && invited.user) {
        const { error: linkError } = await admin.from('company_invitations').update({ invited_user_id: invited.user.id }).eq('id', invitation.id);
        if (linkError) throw linkError;
        return json({ delivery: 'email', invitationId: invitation.id, inviteUrl, expiresAt: invitation.expires_at }, 200, origin);
      }

      let existingUser: { id: string } | null = null;
      for (let page = 1; page <= 100; page += 1) {
        const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
        if (error) throw error;
        existingUser = data.users.find((user) => normalizeEmail(user.email) === email) ?? null;
        if (existingUser || data.users.length < 1000) break;
      }
      if (!existingUser) {
        await admin.from('company_invitations').delete().eq('id', invitation.id);
        throw inviteError ?? new Error('Não foi possível enviar o convite.');
      }
      const { data: existingMember, error: existingMemberError } = await admin.from('company_members')
        .select('user_id').eq('company_id', companyId).eq('user_id', existingUser.id).maybeSingle();
      if (existingMemberError) throw existingMemberError;
      if (existingMember) {
        await admin.from('company_invitations').delete().eq('id', invitation.id);
        return json({ error: 'Esta conta já faz parte da equipe. Altere o papel na lista de integrantes.' }, 409, origin);
      }
      const { error: linkError } = await admin.from('company_invitations').update({ invited_user_id: existingUser.id }).eq('id', invitation.id);
      if (linkError) throw linkError;
      return json({ delivery: 'link', invitationId: invitation.id, inviteUrl, expiresAt: invitation.expires_at }, 200, origin);
    }

    if (action === 'revoke-invitation') {
      const invitationId = String(body.invitationId ?? '');
      if (!isUuid(invitationId)) return json({ error: 'Convite inválido.' }, 400, origin);
      const { data, error } = await admin.from('company_invitations').update({ status: 'revoked' }).eq('id', invitationId).eq('company_id', companyId).eq('status', 'pending').select('id').maybeSingle();
      if (error) throw error;
      if (!data) return json({ error: 'Convite pendente não encontrado.' }, 404, origin);
      return json({ ok: true }, 200, origin);
    }

    if (action === 'update-role') {
      const userId = String(body.userId ?? '');
      const role = String(body.memberRole ?? '');
      if (!isUuid(userId) || (role !== 'recruiter' && role !== 'viewer')) return json({ error: 'Dados do integrante inválidos.' }, 400, origin);
      const { error } = await admin.rpc('company_team_update_member_role_service', {
        p_actor_id: caller.id, p_company_id: companyId, p_user_id: userId, p_member_role: role,
      });
      if (error) throw error;
      return json({ ok: true }, 200, origin);
    }

    if (action === 'remove-member') {
      const userId = String(body.userId ?? '');
      if (!isUuid(userId)) return json({ error: 'Integrante inválido.' }, 400, origin);
      const { error } = await admin.rpc('company_team_remove_member_service', {
        p_actor_id: caller.id, p_company_id: companyId, p_user_id: userId,
      });
      if (error) throw error;
      return json({ ok: true }, 200, origin);
    }

    if (action === 'transfer-owner') {
      const newOwnerId = String(body.userId ?? '');
      if (!isUuid(newOwnerId)) return json({ error: 'Novo proprietário inválido.' }, 400, origin);
      const { error } = await admin.rpc('company_team_transfer_owner_service', {
        p_actor_id: caller.id, p_company_id: companyId, p_new_owner_id: newOwnerId,
      });
      if (error) throw error;
      return json({ ok: true }, 200, origin);
    }

    return json({ error: 'Ação desconhecida.' }, 400, origin);
  } catch (error) {
    console.error('company-team', error);
    const message = error instanceof Error ? error.message : 'Não foi possível atualizar a equipe.';
    return json({ error: message }, 400, origin);
  }
});
