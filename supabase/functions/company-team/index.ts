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
    const companyId = String(body.companyId ?? '');
    if (!companyId || !/^[0-9a-f-]{36}$/i.test(companyId)) return json({ error: 'Empresa inválida.' }, 400, origin);

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

      // Existing accounts cannot be re-invited by Auth. Give the owner a
      // company-scoped claim link; acceptance still checks the signed-in email.
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
      const { data, error } = await admin.from('company_invitations').update({ status: 'revoked' }).eq('id', invitationId).eq('company_id', companyId).eq('status', 'pending').select('id').maybeSingle();
      if (error) throw error;
      if (!data) return json({ error: 'Convite pendente não encontrado.' }, 404, origin);
      return json({ ok: true }, 200, origin);
    }
    return json({ error: 'Ação desconhecida.' }, 400, origin);
  } catch (error) {
    console.error('company-team', error);
    return json({ error: error instanceof Error ? error.message : 'Não foi possível atualizar a equipe.' }, 400, origin);
  }
});
