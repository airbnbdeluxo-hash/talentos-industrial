import { supabase } from './supabase';

type Status='novo'|'triagem'|'entrevista'|'aprovado'|'rejeitado'|'contratado';
export type Evidence={id:string;skill:string;type:string;title:string;issuer:string;verified:boolean;expires?:string;score?:number;storagePath?:string;fileName?:string;mimeType?:string;fileSize?:number;validationStatus?:'pendente'|'aprovada'|'reprovada';reviewedBy?:string;reviewedAt?:string;reviewNote?:string};
export type Candidate={id:string;name:string;city:string;role:string;years:number;salary:number;skills:string[];verified:string[];evidence:Evidence[];shifts:string[];consentGiven?:boolean;bio?:string};
export type Company={id:string;name:string;city:string;industry:string};
export type Job={id:string;title:string;description?:string|null;companyId:string;companyName?:string;city:string;min:number;max:number;skills:string[];status:'aberta'|'pausada'|'fechada';shift:string;createdAt?:string|null;qualifiedCandidateAt?:string|null};
export type AppRow={id:string;jobId:string;candidateId:string;status:Status};
export type AppEvent={id:string;applicationId:string;fromStatus?:Status;toStatus:Status;at:string;note?:string};
export type MatchRow={id:string;jobId:string;candidateId:string;score:number;reasons:string[];gaps:string[]};
export type TrainingStatus='recomendado'|'em_andamento'|'concluido'|'dispensado'|'resolvido';
export type TrainingRecommendation={
  id:string;candidateId:string;jobId:string;skillId:string;skill:string;
  priority:number;reason:string;estimatedHours?:number|null;status:TrainingStatus;
  gapType:'ausente'|'nivel';currentProficiency?:number|null;targetProficiency:number;
  startedAt?:string|null;completedAt?:string|null;updatedAt?:string|null;outcomeNote?:string|null;
};
export type CapabilityNode={id:string;nodeType:'familia'|'processo'|'maquina'|'controle'|'competencia'|'cargo'|'contexto';name:string;slug:string;skillId?:string|null;parentId?:string|null;description?:string|null};
export type CapabilityEdge={fromNodeId:string;toNodeId:string;relationshipType:'inclui'|'exige'|'usa'|'aplicada_em'|'proximo_de'|'desenvolve_para';weight:number;source:string};
export type OutcomeCheckpoint='30d'|'60d'|'90d'|'saida';
export type RetentionStatus='ativo'|'desligado'|'promovido'|'transferido';
export type EmploymentOutcome={id:string;applicationId:string;candidateId:string;jobId:string;companyId:string;checkpoint:OutcomeCheckpoint;performanceScore?:number|null;rampUpDays?:number|null;retentionStatus:RetentionStatus;skillFeedback:Record<string,unknown>;managerNote?:string|null;createdBy:string;createdAt:string;updatedAt:string};
export type OutcomeSkillSignalStatus='utilizada'|'necessita_desenvolvimento'|'nao_observado'|'nao_aplicavel';
export type EmploymentOutcomeSkillSignal={id:string;outcomeId:string;skillId:string;capabilityNodeId?:string|null;skill:string;signalStatus:OutcomeSkillSignalStatus;managerRating?:number|null;trainingNeeded:boolean;note?:string|null;createdBy:string;createdAt:string;updatedAt:string};
export type OutcomeSkillIntelligence={skillId:string;capabilityNodeId?:string|null;skillName:string;signalCount:number;utilizedCount:number;needsDevelopmentCount:number;trainingNeededCount:number;avgManagerRating?:number|null;avgPerformance?:number|null;avgRampUpDays?:number|null};
export type DB={candidates:Candidate[];companies:Company[];jobs:Job[];applications:AppRow[];events:AppEvent[];matches:MatchRow[];training:TrainingRecommendation[];capabilityNodes:CapabilityNode[];capabilityEdges:CapabilityEdge[];outcomes:EmploymentOutcome[];outcomeSkillSignals:EmploymentOutcomeSkillSignal[]};
export type RemoteProfile={id:string;role:'empresa'|'candidato'|'admin';full_name:string;city?:string|null};
export type ChallengeQuestion={id:string;text:string;options:string[]};
export type Challenge={id:string;skillId:string;skill:string;title:string;description:string;difficulty:string;timeLimitMinutes:number;questions:ChallengeQuestion[]};

const mapEvidence=(e:any):Evidence=>({id:e.id,skill:e.skills?.name??'Skill',type:e.evidence_type,title:e.title,issuer:e.issuer??'',verified:Boolean(e.verified),expires:e.expires_at??undefined,score:e.score??undefined,storagePath:e.storage_path??undefined,fileName:e.file_name??undefined,mimeType:e.mime_type??undefined,fileSize:e.file_size??undefined,validationStatus:e.validation_status??'pendente',reviewedBy:e.reviewed_by??undefined,reviewedAt:e.reviewed_at??undefined,reviewNote:e.review_note??undefined});
const mapCandidate=(c:any):Candidate=>{
 const prefs=Array.isArray(c.talent_preferences)?c.talent_preferences[0]:c.talent_preferences;
 return {id:c.profile_id,name:c.display_name??'Talento',city:c.city??'',role:c.role_title??'Profissional industrial',years:Number(c.years_experience??0),salary:Number(c.desired_salary??0),bio:c.bio??undefined,skills:(c.candidate_skills??[]).map((x:any)=>x.skills?.name).filter(Boolean),verified:(c.candidate_skills??[]).filter((x:any)=>x.verified).map((x:any)=>x.skills?.name).filter(Boolean),evidence:(c.skill_evidence??[]).map(mapEvidence),shifts:prefs?.preferred_shifts??[],consentGiven:Boolean(c.visibility_consent_at&&c.consent_version)};
};
const mapCompany=(c:any):Company=>({id:c.id,name:c.name,city:c.city,industry:c.industry??'Indústria'});
const mapJob=(j:any):Job=>({id:j.id,title:j.title,description:j.description??null,companyId:j.company_id,companyName:j.company_public_name??undefined,city:j.city,min:Number(j.salary_min??0),max:Number(j.salary_max??0),skills:[],status:j.status,shift:j.shift??'1º turno',createdAt:j.created_at??null,qualifiedCandidateAt:j.qualified_candidate_at??null});
const mapApplication=(a:any):AppRow=>({id:a.id,jobId:a.job_id,candidateId:a.candidate_id,status:a.status as Status});
const mapEvent=(e:any):AppEvent=>({id:e.id,applicationId:e.application_id,fromStatus:(e.from_status??undefined) as Status|undefined,toStatus:e.to_status as Status,at:e.created_at,note:e.note??undefined});
const mapMatch=(m:any):MatchRow=>({id:m.id,jobId:m.job_id,candidateId:m.candidate_id,score:Number(m.score??0),reasons:Array.isArray(m.reasons)?m.reasons.map(String):[],gaps:Array.isArray(m.gaps)?m.gaps.map(String):[]});
const mapTraining=(t:any):TrainingRecommendation=>({
  id:t.id,candidateId:t.candidate_id,jobId:t.job_id,skillId:t.skill_id,skill:t.skills?.name??'Skill',
  priority:Number(t.priority??3),reason:t.reason,estimatedHours:t.estimated_hours==null?null:Number(t.estimated_hours),
  status:t.status as TrainingStatus,gapType:(t.gap_type??'nivel') as 'ausente'|'nivel',
  currentProficiency:t.current_proficiency==null?null:Number(t.current_proficiency),
  targetProficiency:Number(t.target_proficiency??3),startedAt:t.started_at??null,
  completedAt:t.completed_at??null,updatedAt:t.updated_at??null,outcomeNote:t.outcome_note??null
});
const mapChallenge=(c:any):Challenge=>({id:c.id,skillId:c.skill_id,skill:c.skills?.name??'Skill',title:c.title,description:c.description,difficulty:c.difficulty,timeLimitMinutes:Number(c.time_limit_minutes??10),questions:Array.isArray(c.questions)?c.questions.map((q:any)=>({id:String(q.id),text:String(q.text),options:Array.isArray(q.options)?q.options.map(String):[]})):[]});
const mapCapabilityNode=(n:any):CapabilityNode=>({id:n.id,nodeType:n.node_type,name:n.name,slug:n.slug,skillId:n.skill_id??null,parentId:n.parent_id??null,description:n.description??null});
const mapCapabilityEdge=(e:any):CapabilityEdge=>({fromNodeId:e.from_node_id,toNodeId:e.to_node_id,relationshipType:e.relationship_type,weight:Number(e.weight??1),source:e.source??'TalentOS'});
const mapOutcome=(o:any):EmploymentOutcome=>({id:o.id,applicationId:o.application_id,candidateId:o.candidate_id,jobId:o.job_id,companyId:o.company_id,checkpoint:o.checkpoint as OutcomeCheckpoint,performanceScore:o.performance_score==null?null:Number(o.performance_score),rampUpDays:o.ramp_up_days==null?null:Number(o.ramp_up_days),retentionStatus:o.retention_status as RetentionStatus,skillFeedback:(o.skill_feedback&&typeof o.skill_feedback==='object')?o.skill_feedback:{},managerNote:o.manager_note??null,createdBy:o.created_by,createdAt:o.created_at,updatedAt:o.updated_at});
const mapOutcomeSkillSignal=(s:any):EmploymentOutcomeSkillSignal=>({id:s.id,outcomeId:s.outcome_id,skillId:s.skill_id,capabilityNodeId:s.capability_node_id??null,skill:s.skills?.name??'Skill',signalStatus:s.signal_status as OutcomeSkillSignalStatus,managerRating:s.manager_rating==null?null:Number(s.manager_rating),trainingNeeded:Boolean(s.training_needed),note:s.note??null,createdBy:s.created_by,createdAt:s.created_at,updatedAt:s.updated_at});

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
 const [companyRes,jobsRes,candidatesRes,appsRes,eventsRes,matchesRes,trainingRes,capabilityNodesRes,capabilityEdgesRes,outcomesRes,outcomeSkillSignalsRes]=await Promise.all([
   companyQuery,
   supabase.from('jobs').select('*').order('created_at',{ascending:false}),
   supabase.from('candidate_profiles').select('profile_id,display_name,role_title,years_experience,desired_salary,bio,city,searchable,candidate_skills(skill_id,proficiency,verified,years_experience,skills(name)),skill_evidence(id,skill_id,evidence_type,title,issuer,verified,verified_at,expires_at,score,storage_path,file_name,mime_type,file_size,validation_status,reviewed_by,reviewed_at,review_note,skills(name)),talent_preferences(preferred_shifts)').or(`searchable.eq.true,profile_id.eq.${userId}`),
   supabase.from('applications').select('*').order('updated_at',{ascending:false}),
   supabase.from('application_events').select('*').order('created_at',{ascending:true}),
   supabase.from('matches').select('*').order('score',{ascending:false}),
   supabase.from('training_recommendations').select('id,candidate_id,job_id,skill_id,priority,reason,estimated_hours,status,gap_type,current_proficiency,target_proficiency,started_at,completed_at,updated_at,outcome_note,skills(name)').order('updated_at',{ascending:false}),
   supabase.from('capability_nodes').select('id,node_type,name,slug,skill_id,parent_id,description').order('node_type',{ascending:true}).order('name',{ascending:true}),
   supabase.from('capability_edges').select('from_node_id,to_node_id,relationship_type,weight,source').order('relationship_type',{ascending:true}),
   supabase.from('employment_outcomes').select('id,application_id,candidate_id,job_id,company_id,checkpoint,performance_score,ramp_up_days,retention_status,skill_feedback,manager_note,created_by,created_at,updated_at').order('created_at',{ascending:false}),
   supabase.from('employment_outcome_skill_signals').select('id,outcome_id,skill_id,capability_node_id,signal_status,manager_rating,training_needed,note,created_by,created_at,updated_at,skills(name)').order('created_at',{ascending:false})
 ]);
 if(companyRes.error)throw companyRes.error;if(jobsRes.error)throw jobsRes.error;if(candidatesRes.error)throw candidatesRes.error;if(appsRes.error)throw appsRes.error;if(eventsRes.error)throw eventsRes.error;if(matchesRes.error)throw matchesRes.error;if(trainingRes.error)throw trainingRes.error;if(capabilityNodesRes.error)throw capabilityNodesRes.error;if(capabilityEdgesRes.error)throw capabilityEdgesRes.error;if(outcomesRes.error)throw outcomesRes.error;if(outcomeSkillSignalsRes.error)throw outcomeSkillSignalsRes.error;
 const jobIds=(jobsRes.data??[]).map((j:any)=>j.id);
 let jobSkills:any[]=[];
 if(jobIds.length){const r=await supabase.from('job_skills').select('job_id,skill_id,skills(name)').in('job_id',jobIds);if(r.error)throw r.error;jobSkills=r.data??[];}
 const jobs=(jobsRes.data??[]).map((j:any)=>({...mapJob(j),skills:jobSkills.filter(s=>s.job_id===j.id).map(s=>s.skills?.name).filter(Boolean)}));
 return {candidates:(candidatesRes.data??[]).map(mapCandidate),companies:(companyRes.data??[]).map(mapCompany),jobs,applications:(appsRes.data??[]).map(mapApplication),events:(eventsRes.data??[]).map(mapEvent),matches:(matchesRes.data??[]).map(mapMatch),training:(trainingRes.data??[]).map(mapTraining),capabilityNodes:(capabilityNodesRes.data??[]).map(mapCapabilityNode),capabilityEdges:(capabilityEdgesRes.data??[]).map(mapCapabilityEdge),outcomes:(outcomesRes.data??[]).map(mapOutcome),outcomeSkillSignals:(outcomeSkillSignalsRes.data??[]).map(mapOutcomeSkillSignal)};
}

async function findSkillIds(names:string[]):Promise<{id:string,name:string}[]>{
 if(!supabase||!names.length)return [];
 const {data,error}=await supabase.from('skills').select('id,name').in('name',names);
 if(error)throw error;return data??[];
}

export async function getRemoteSkills():Promise<string[]>{
 if(!supabase)throw new Error('Supabase não configurado');
 const {data,error}=await supabase.from('skills').select('name').order('name',{ascending:true});
 if(error)throw error;
 return (data??[]).map((x:any)=>x.name).filter(Boolean);
}

export async function createRemoteCompany(userId:string, input:{name:string;city:string;industry:string}){
 if(!supabase)throw new Error('Supabase não configurado');
 const {data:company,error}=await supabase.from('companies').insert({name:input.name,city:input.city,state:'RS',industry:input.industry,created_by:userId}).select('*').single();
 if(error)throw error;
 const member=await supabase.from('company_members').insert({company_id:company.id,user_id:userId,member_role:'owner'});
 if(member.error)throw member.error;
 return company;
}

export async function createRemoteJob(userId:string,input:{title:string;description?:string;companyId:string;city:string;min:number;max:number;shift:string;skills:string[]}){
 if(!supabase)throw new Error('Supabase não configurado');
 const company=await supabase.from('companies').select('name').eq('id',input.companyId).single();if(company.error)throw company.error;
 const {data:job,error}=await supabase.from('jobs').insert({title:input.title,description:input.description?.trim()||null,company_id:input.companyId,company_public_name:company.data.name,city:input.city,salary_min:input.min,salary_max:input.max,shift:input.shift,status:'aberta'}).select('*').single();
 if(error)throw error;
 const skills=await findSkillIds(input.skills);
 if(skills.length) {
   const rows=skills.map(s=>({job_id:job.id,skill_id:s.id,required:true,min_proficiency:3,weight:1}));
   const r=await supabase.from('job_skills').insert(rows);if(r.error)throw r.error;
 }
 return job;
}

export async function createRemoteCandidate(userId:string,input:{name:string;role:string;city:string;years:number;salary:number;skills:string[];preferredShifts?:string[];searchable?:boolean;bio?:string}){
 if(!supabase)throw new Error('Supabase não configurado');
 const consented=input.searchable!==false;
 const {error:profileError}=await supabase.from('candidate_profiles').upsert({profile_id:userId,display_name:input.name,role_title:input.role,city:input.city,years_experience:input.years,desired_salary:input.salary,bio:input.bio?.trim()||null,searchable:consented,visibility_consent_at:consented?new Date().toISOString():null,consent_version:consented?'v1':null}, {onConflict:'profile_id'});
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

export async function generateRemoteTrainingRecommendations(candidateId:string,jobId:string){
 if(!supabase)throw new Error('Supabase não configurado');
 const {data,error}=await supabase.rpc('generate_training_plan_for_job',{p_candidate_id:candidateId,p_job_id:jobId});
 if(error)throw error;
 return (data??[]).map(mapTraining);
}

export async function updateRemoteTrainingRecommendation(
 recommendationId:string,
 status:Exclude<TrainingStatus,'recomendado'|'resolvido'>,
 note?:string
){
 if(!supabase)throw new Error('Supabase não configurado');
 const {data,error}=await supabase.rpc('update_training_recommendation',{
   p_recommendation_id:recommendationId,p_status:status,p_note:note??null
 });
 if(error)throw error;
 return data ? mapTraining(data) : null;
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


export async function recordRemoteEmploymentOutcome(input:{applicationId:string;checkpoint:OutcomeCheckpoint;performanceScore?:number|null;rampUpDays?:number|null;retentionStatus:RetentionStatus;skillFeedback?:Record<string,unknown>;managerNote?:string|null}){
 if(!supabase)throw new Error('Supabase não configurado');
 const {data,error}=await supabase.rpc('record_employment_outcome',{
   p_application_id:input.applicationId,
   p_checkpoint:input.checkpoint,
   p_performance_score:input.performanceScore??null,
   p_ramp_up_days:input.rampUpDays??null,
   p_retention_status:input.retentionStatus,
   p_skill_feedback:input.skillFeedback??{},
   p_manager_note:input.managerNote??null
 });
 if(error)throw error;
 return data?mapOutcome(data):null;
}


export async function saveRemoteOutcomeSkillSignal(input:{outcomeId:string;skillId:string;signalStatus:OutcomeSkillSignalStatus;managerRating?:number|null;trainingNeeded?:boolean;note?:string|null}){
 if(!supabase)throw new Error('Supabase não configurado');
 const {data,error}=await supabase.rpc('save_employment_outcome_skill_signal',{
   p_outcome_id:input.outcomeId,
   p_skill_id:input.skillId,
   p_signal_status:input.signalStatus,
   p_manager_rating:input.managerRating??null,
   p_training_needed:Boolean(input.trainingNeeded),
   p_note:input.note??null
 });
 if(error)throw error;
 return data?mapOutcomeSkillSignal(data):null;
}


export async function getRemoteOutcomeSkillIntelligence():Promise<OutcomeSkillIntelligence[]>{
 if(!supabase)throw new Error('Supabase não configurado');
 const {data,error}=await supabase.rpc('get_company_outcome_skill_intelligence');
 if(error)throw error;
 return (data??[]).map((row:any)=>({skillId:row.skill_id,capabilityNodeId:row.capability_node_id??null,skillName:row.skill_name??'Skill',signalCount:Number(row.signal_count??0),utilizedCount:Number(row.utilized_count??0),needsDevelopmentCount:Number(row.needs_development_count??0),trainingNeededCount:Number(row.training_needed_count??0),avgManagerRating:row.avg_manager_rating==null?null:Number(row.avg_manager_rating),avgPerformance:row.avg_performance==null?null:Number(row.avg_performance),avgRampUpDays:row.avg_ramp_up_days==null?null:Number(row.avg_ramp_up_days)}));
}


export async function saveRemoteCandidateConsent(userId:string,consentGiven:boolean,consentVersion='v1'){ if(!supabase)throw new Error('Supabase não configurado'); const {data,error}=await supabase.from('candidate_profiles').update({searchable:consentGiven,visibility_consent_at:consentGiven?new Date().toISOString():null,consent_version:consentGiven?consentVersion:null}).eq('profile_id',userId).select('profile_id,searchable,visibility_consent_at,consent_version').single(); if(error)throw error; return data; }
