import { supabase } from './supabase';

type Status='novo'|'triagem'|'entrevista'|'aprovado'|'rejeitado'|'contratado';
export type Evidence={id:string;skill:string;type:string;title:string;issuer:string;verified:boolean;expires?:string;score?:number;storagePath?:string;fileName?:string;mimeType?:string;fileSize?:number;validationStatus?:'pendente'|'aprovada'|'reprovada';reviewedBy?:string;reviewedAt?:string;reviewNote?:string};
export type Candidate={id:string;name:string;city:string;role:string;years:number;salary:number;skills:string[];verified:string[];evidence:Evidence[];shifts:string[];consentGiven?:boolean};
export type Company={id:string;name:string;city:string;industry:string};
export type Job={id:string;title:string;companyId:string;companyName?:string;city:string;min:number;max:number;skills:string[];status:'aberta'|'pausada'|'fechada';shift:string;createdAt?:string|null;qualifiedCandidateAt?:string|null};
export type AppRow={id:string;jobId:string;candidateId:string;status:Status};
export type AppEvent={id:string;applicationId:string;fromStatus?:Status;toStatus:Status;at:string;note?:string};
export type MatchRow={id:string;jobId:string;candidateId:string;score:number;reasons:string[];gaps:string[]};
export type DB={candidates:Candidate[];companies:Company[];jobs:Job[];applications:AppRow[];events:AppEvent[];matches:MatchRow[]};
export type RemoteProfile={id:string;role:'empresa'|'candidato'|'admin';full_name:string;city?:string|null};
export type ChallengeQuestion={id:string;text:string;options:string[]};
export type Challenge={id:string;skillId:string;skill:string;title:string;description:string;difficulty:string;timeLimitMinutes:number;questions:ChallengeQuestion[]};

const mapEvidence=(e:any):Evidence=>({id:e.id,skill:e.skills?.name??'Skill',type:e.evidence_type,title:e.title,issuer:e.issuer??'',verified:Boolean(e.verified),expires:e.expires_at??undefined,score:e.score??undefined,storagePath:e.storage_path??undefined,fileName:e.file_name??undefined,mimeType:e.mime_type??undefined,fileSize:e.file_size??undefined,validationStatus:e.validation_status??'pendente',reviewedBy:e.reviewed_by??undefined,reviewedAt:e.reviewed_at??undefined,reviewNote:e.review_note??undefined});
const mapCandidate=(c:any):Candidate=>{
 const prefs=Array.isArray(c.talent_preferences)?c.talent_preferences[0]:c.talent_preferences;
 return {id:c.profile_id,name:c.display_name??'Talento',city:c.city??'',role:c.role_title??'Profissional industrial',years:Number(c.years_experience??0),salary:Number(c.desired_salary??0),skills:(c.candidate_skills??[]).map((x:any)=>x.skills?.name).filter(Boolean),verified:(c.candidate_skills??[]).filter((x:any)=>x.verified).map((x:any)=>x.skills?.name).filter(Boolean),evidence:(c.skill_evidence??[]).map(mapEvidence),shifts:prefs?.preferred_shifts??[],consentGiven:Boolean(c.visibility_consent_at&&c.consent_version)};
};
const mapCompany=(c:any):Company=>({id:c.id,name:c.name,city:c.city,industry:c.industry??'Indústria'});
const mapJob=(j:any):Job=>({id:j.id,title:j.title,companyId:j.company_id,companyName:j.company_public_name??undefined,city:j.city,min:Number(j.salary_min??0),max:Number(j.salary_max??0),skills:[],status:j.status,shift:j.shift??'1º turno',createdAt:j.created_at??null,qualifiedCandidateAt:j.qualified_candidate_at??null});
const mapApplication=(a:any):AppRow=>({id:a.id,jobId:a.job_id,candidateId:a.candidate_id,status:a.status as Status});
const mapEvent=(e:any):AppEvent=>({id:e.id,applicationId:e.application_id,fromStatus:(e.from_status??undefined) as Status|undefined,toStatus:e.to_status as Status,at:e.created_at,note:e.note??undefined});
const mapMatch=(m:any):MatchRow=>({id:m.id,jobId:m.job_id,candidateId:m.candidate_id,score:Number(m.score??0),reasons:Array.isArray(m.reasons)?m.reasons.map(String):[],gaps:Array.isArray(m.gaps)?m.gaps.map(String):[]});
const mapChallenge=(c:any):Challenge=>({id:c.id,skillId:c.skill_id,skill:c.skills?.name??'Skill',title:c.title,description:c.description,difficulty:c.difficulty,timeLimitMinutes:Number(c.time_limit_minutes??10),questions:Array.isArray(c.questions)?c.questions.map((q:any)=>({id:String(q.id),text:String(q.text),options:Array.isArray(q.options)?q.options.map(String):[]})):[]});

export async function getRemoteProfile(userId:string):Promise<RemoteProfile|null>{
 if(!supabase)return null;
 const {data,error}=await supabase.from('profiles').select('id,role,full_name,city').eq('id',userId).maybeSingle();
 if(error)throw error;
 return data as RemoteProfile|null;
}

export async function loadRemoteData(userId:string):Promise<DB>{
 if(!supabase)throw new Error('Supabase não configurado');
 const {data:members,error:memberError}=await supabase.from('company_members').select('company_id').eq('user_id',userId);
 if(memberError)throw memberError;
 const companyIds=(members??[]).map((x:any)=>x.company_id);
 const companyQuery=companyIds.length?supabase.from('companies').select('*').in('id',companyIds):Promise.resolve({data:[],error:null} as any);
 const [companyRes,jobsRes,candidatesRes,appsRes,eventsRes,matchesRes]=await Promise.all([
   companyQuery,
   supabase.from('jobs').select('*').order('created_at',{ascending:false}),
   supabase.from('candidate_profiles').select('profile_id,display_name,role_title,years_experience,desired_salary,city,searchable,candidate_skills(skill_id,proficiency,verified,years_experience,skills(name)),skill_evidence(id,skill_id,evidence_type,title,issuer,verified,verified_at,expires_at,score,storage_path,file_name,mime_type,file_size,validation_status,reviewed_by,reviewed_at,review_note,skills(name)),talent_preferences(preferred_shifts)').or(`searchable.eq.true,profile_id.eq.${userId}`),
   supabase.from('applications').select('*').order('updated_at',{ascending:false}),
   supabase.from('application_events').select('*').order('created_at',{ascending:true}),
   supabase.from('matches').select('*').order('score',{ascending:false})
 ]);
 if(companyRes.error)throw companyRes.error;if(jobsRes.error)throw jobsRes.error;if(candidatesRes.error)throw candidatesRes.error;if(appsRes.error)throw appsRes.error;if(eventsRes.error)throw eventsRes.error;if(matchesRes.error)throw matchesRes.error;
 const jobIds=(jobsRes.data??[]).map((j:any)=>j.id);
 let jobSkills:any[]=[];
 if(jobIds.length){const r=await supabase.from('job_skills').select('job_id,skill_id,skills(name)').in('job_id',jobIds);if(r.error)throw r.error;jobSkills=r.data??[];}
 const jobs=(jobsRes.data??[]).map((j:any)=>({...mapJob(j),skills:jobSkills.filter(s=>s.job_id===j.id).map(s=>s.skills?.name).filter(Boolean)}));
 return {candidates:(candidatesRes.data??[]).map(mapCandidate),companies:(companyRes.data??[]).map(mapCompany),jobs,applications:(appsRes.data??[]).map(mapApplication),events:(eventsRes.data??[]).map(mapEvent),matches:(matchesRes.data??[]).map(mapMatch)};
}

async function findSkillIds(names:string[]):Promise<{id:string,name:string}[]>{
 if(!supabase||!names.length)return [];
 const {data,error}=await supabase.from('skills').select('id,name').in('name',names);
 if(error)throw error;return data??[];
}

export async function createRemoteCompany(userId:string, input:{name:string;city:string;industry:string}){
 if(!supabase)throw new Error('Supabase não configurado');
 const {data:company,error}=await supabase.from('companies').insert({name:input.name,city:input.city,state:'RS',industry:input.industry,created_by:userId}).select('*').single();
 if(error)throw error;
 const member=await supabase.from('company_members').insert({company_id:company.id,user_id:userId,member_role:'owner'});
 if(member.error)throw member.error;
 return company;
}

export async function createRemoteJob(userId:string,input:{title:string;companyId:string;city:string;min:number;max:number;shift:string;skills:string[]}){
 if(!supabase)throw new Error('Supabase não configurado');
 const company=await supabase.from('companies').select('name').eq('id',input.companyId).single();if(company.error)throw company.error;
 const {data:job,error}=await supabase.from('jobs').insert({title:input.title,company_id:input.companyId,company_public_name:company.data.name,city:input.city,salary_min:input.min,salary_max:input.max,shift:input.shift,status:'aberta'}).select('*').single();
 if(error)throw error;
 const skills=await findSkillIds(input.skills);
 if(skills.length) {
   const rows=skills.map(s=>({job_id:job.id,skill_id:s.id,required:true,min_proficiency:3,weight:1}));
   const r=await supabase.from('job_skills').insert(rows);if(r.error)throw r.error;
 }
 return job;
}

export async function createRemoteCandidate(userId:string,input:{name:string;role:string;city:string;years:number;salary:number;skills:string[];preferredShifts?:string[];searchable?:boolean}){
 if(!supabase)throw new Error('Supabase não configurado');
 const consented=input.searchable!==false;
 const {error:profileError}=await supabase.from('candidate_profiles').upsert({profile_id:userId,display_name:input.name,role_title:input.role,city:input.city,years_experience:input.years,desired_salary:input.salary,searchable:consented,visibility_consent_at:consented?new Date().toISOString():null,consent_version:consented?'v1':null}, {onConflict:'profile_id'});
 if(profileError)throw profileError;
 const skills=await findSkillIds(input.skills);
 if(input.preferredShifts){
   const pref=await supabase.from('talent_preferences').upsert({candidate_id:userId,preferred_shifts:input.preferredShifts},{onConflict:'candidate_id'});
   if(pref.error)throw pref.error;
 }
 if(skills.length){
   await supabase.from('candidate_skills').delete().eq('candidate_id',userId);
   const r=await supabase.from('candidate_skills').insert(skills.map(s=>({candidate_id:userId,skill_id:s.id,proficiency:3,verified:false,years_experience:input.years})));
   if(r.error)throw r.error;
 }
}

export async function updateRemoteApplication(applicationId:string,status:Status){
 if(!supabase)throw new Error('Supabase não configurado');
 const {error}=await supabase.from('applications').update({status,updated_at:new Date().toISOString()}).eq('id',applicationId);
 if(error)throw error;
}

export async function applyToJob(userId:string,jobId:string){
 if(!supabase)throw new Error('Supabase não configurado');
 const {error}=await supabase.from('applications').insert({candidate_id:userId,job_id:jobId,status:'novo'});
 if(error)throw error;
}

export async function generateRemoteMatches(jobId:string){
 if(!supabase)throw new Error('Supabase não configurado');
 const {data,error}=await supabase.rpc('generate_matches_for_job',{p_job_id:jobId});
 if(error)throw error;
 return (data??[]) as Array<{candidate_id:string;score:number;reasons:any;gaps:any}>;
}

export async function uploadRemoteEvidence(userId:string,skillName:string,file:File){
 if(!supabase)throw new Error('Supabase não configurado');
 if(file.size>10*1024*1024)throw new Error('Arquivo maior que 10 MB');
 const allowed=['application/pdf','image/jpeg','image/png','image/webp','text/plain'];
 if(file.type&&!allowed.includes(file.type))throw new Error('Formato não suportado');
 const {data:skill,error:skillError}=await supabase.from('skills').select('id,name').eq('name',skillName).maybeSingle();
 if(skillError)throw skillError;
 if(!skill)throw new Error('Skill não encontrada');
 const safe=file.name.replace(/[^a-zA-Z0-9._-]/g,'_');
 const storagePath=userId+'/'+skill.id+'/'+crypto.randomUUID()+'-'+safe;
 const upload=await supabase.storage.from('skill-evidence').upload(storagePath,file,{contentType:file.type||'application/octet-stream',upsert:false});
 if(upload.error)throw upload.error;
 const evidence=await supabase.from('skill_evidence').insert({
   candidate_id:userId,skill_id:skill.id,evidence_type:'certificado',title:file.name,issuer:'Enviado pelo profissional',
   verified:false,storage_path:storagePath,file_name:file.name,mime_type:file.type||null,file_size:file.size
 }).select('id,storage_path,file_name,mime_type,file_size').single();
 if(evidence.error){
   await supabase.storage.from('skill-evidence').remove([storagePath]);
   throw evidence.error;
 }
 return evidence.data;
}

export async function getEvidenceDownloadUrl(storagePath:string){
 if(!supabase)throw new Error('Supabase não configurado');
 const {data,error}=await supabase.storage.from('skill-evidence').createSignedUrl(storagePath,300);
 if(error)throw error;
 return data.signedUrl;
}

export async function getRemoteChallenges(skillName:string){
 if(!supabase)throw new Error('Supabase não configurado');
 const skillRes=await supabase.from('skills').select('id,name').eq('name',skillName).maybeSingle();
 if(skillRes.error)throw skillRes.error;
 if(!skillRes.data)return [];
 const {data,error}=await supabase.from('challenge_library').select('id,skill_id,title,description,difficulty,time_limit_minutes,questions').eq('active',true).eq('skill_id',skillRes.data.id).order('created_at',{ascending:true});
 if(error)throw error;
 return (data??[]).map((x:any)=>mapChallenge({...x,skills:{name:skillName}}));
}

export async function startRemoteChallenge(challengeId:string,jobId?:string){
 if(!supabase)throw new Error('Supabase não configurado');
 const {data,error}=await supabase.rpc('start_challenge',{p_challenge_id:challengeId,p_job_id:jobId??null});
 if(error)throw error;
 return String(data);
}

export async function completeRemoteChallenge(attemptId:string,answers:Record<string,number>){
 if(!supabase)throw new Error('Supabase não configurado');
 const {data,error}=await supabase.rpc('complete_challenge',{p_attempt_id:attemptId,p_answers:answers});
 if(error)throw error;
 return data?.[0] as {score:number|null;correct_count:number|null;total_count:number}|undefined;
}


export async function reviewRemoteEvidence(evidenceId:string,status:'aprovada'|'reprovada',note?:string){
 if(!supabase)throw new Error('Supabase não configurado');
 const {data,error}=await supabase.rpc('review_skill_evidence',{p_evidence_id:evidenceId,p_status:status,p_note:note??null});
 if(error)throw error;
 return data;
}
