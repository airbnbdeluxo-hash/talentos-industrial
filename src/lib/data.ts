import { supabase } from './supabase';

type Status='novo'|'triagem'|'entrevista'|'aprovado'|'rejeitado'|'contratado';
export type Evidence={id:string;skill:string;type:string;title:string;issuer:string;verified:boolean;expires?:string;score?:number;storagePath?:string;fileName?:string;mimeType?:string;fileSize?:number;validationStatus?:'pendente'|'aprovada'|'reprovada';reviewedBy?:string;reviewedAt?:string;reviewNote?:string;fileHash?:string;integrityStatus?:'normal'|'duplicado'|'revisao'};
export type Candidate={id:string;name:string;city:string;role:string;years:number;salary:number;skills:string[];verified:string[];evidence:Evidence[];shifts:string[];consentGiven?:boolean;bio?:string};
export type Company={id:string;name:string;city:string;industry:string};
export type Job={id:string;title:string;description?:string|null;companyId:string;companyName?:string;city:string;min:number;max:number;skills:string[];status:'aberta'|'pausada'|'fechada';shift:string;createdAt?:string|null;qualifiedCandidateAt?:string|null;publicSlug?:string|null;screeningQuestions:string[];employmentType?:string;workModel?:string;benefits?:string[];travelRequired?:boolean;interviewQuestions:string[]};
export type AppRow={id:string;jobId:string;candidateId:string;status:Status;source?:string|null;sourceDetail?:string|null;screeningAnswers?:Record<string,string>};
export type SavedJob={id:string;candidateId:string;jobId:string;createdAt:string};
export type JobAlert={id:string;candidateId:string;name:string;cargo?:string|null;skill?:string|null;city?:string|null;minSalary?:number|null;maxSalary?:number|null;shift?:string|null;workModel?:string|null;active:boolean;createdAt:string;updatedAt:string};
export type Message={id:string;applicationId:string;senderId:string;recipientId:string;body:string;readAt?:string|null;createdAt:string};
export type InterviewStatus='agendada'|'confirmada'|'cancelada'|'realizada';
export type Interview={id:string;applicationId:string;scheduledAt:string;durationMinutes:number;mode:'online'|'presencial';location?:string|null;meetingUrl?:string|null;interviewerId?:string|null;status:InterviewStatus;notes?:string|null;createdAt:string;updatedAt:string};
export type InterviewScorecard={id:string;applicationId:string;interviewerId:string;competency:string;rating:number;evidenceNote?:string|null;createdAt:string};
export type TalentPool={id:string;companyId:string;name:string;description?:string|null;createdBy:string;createdAt:string};
export type TalentPoolMember={poolId:string;candidateId:string;notes?:string|null;createdAt:string};
export type OfferStatus='enviada'|'aceita'|'recusada'|'cancelada';
export type Offer={id:string;applicationId:string;salary?:number|null;startDate?:string|null;message?:string|null;status:OfferStatus;createdBy:string;respondedAt?:string|null;createdAt:string;updatedAt:string};
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
export type DB={candidates:Candidate[];companies:Company[];jobs:Job[];applications:AppRow[];events:AppEvent[];matches:MatchRow[];training:TrainingRecommendation[];capabilityNodes:CapabilityNode[];capabilityEdges:CapabilityEdge[];outcomes:EmploymentOutcome[];outcomeSkillSignals:EmploymentOutcomeSkillSignal[];savedJobs:SavedJob[];jobAlerts:JobAlert[];messages:Message[];interviews:Interview[];scorecards:InterviewScorecard[];talentPools:TalentPool[];talentPoolMembers:TalentPoolMember[];offers:Offer[];notifications:Notification[];applicationNotes:ApplicationNote[];jobEngagementEvents:JobEngagementEvent[];candidateAvailability:CandidateAvailability[]};
export type RemoteProfile={id:string;role:'empresa'|'candidato'|'admin';full_name:string;city?:string|null};
export type ChallengeQuestion={id:string;text:string;options:string[]};
export type Challenge={id:string;skillId:string;skill:string;title:string;description:string;difficulty:string;timeLimitMinutes:number;questions:ChallengeQuestion[]};

const mapEvidence=(e:any):Evidence=>({id:e.id,skill:e.skills?.name??'Skill',type:e.evidence_type,title:e.title,issuer:e.issuer??'',verified:Boolean(e.verified),expires:e.expires_at??undefined,score:e.score??undefined,storagePath:e.storage_path??undefined,fileName:e.file_name??undefined,mimeType:e.mime_type??undefined,fileSize:e.file_size??undefined,validationStatus:e.validation_status??'pendente',reviewedBy:e.reviewed_by??undefined,reviewedAt:e.reviewed_at??undefined,reviewNote:e.review_note??undefined,fileHash:e.file_hash??undefined,integrityStatus:e.integrity_status??'normal'});
const mapCandidate=(c:any):Candidate=>{
 const prefs=Array.isArray(c.talent_preferences)?c.talent_preferences[0]:c.talent_preferences;
 return {id:c.profile_id,name:c.display_name??'Talento',city:c.city??'',role:c.role_title??'Profissional industrial',years:Number(c.years_experience??0),salary:Number(c.desired_salary??0),bio:c.bio??undefined,skills:(c.candidate_skills??[]).map((x:any)=>x.skills?.name).filter(Boolean),verified:(c.candidate_skills??[]).filter((x:any)=>x.verified).map((x:any)=>x.skills?.name).filter(Boolean),evidence:(c.skill_evidence??[]).map(mapEvidence),shifts:prefs?.preferred_shifts??[],consentGiven:Boolean(c.visibility_consent_at&&c.consent_version)};
};
const mapCompany=(c:any):Company=>({id:c.id,name:c.name,city:c.city,industry:c.industry??'Indústria'});
const mapJob=(j:any):Job=>({id:j.id,title:j.title,description:j.description??null,companyId:j.company_id,companyName:j.company_public_name??undefined,city:j.city,min:Number(j.salary_min??0),max:Number(j.salary_max??0),skills:[],status:j.status,shift:j.shift??'1º turno',createdAt:j.created_at??null,qualifiedCandidateAt:j.qualified_candidate_at??null,publicSlug:j.public_slug??null,screeningQuestions:Array.isArray(j.screening_questions)?j.screening_questions.map(String):[],employmentType:j.employment_type??'CLT',workModel:j.work_model??'Presencial',benefits:Array.isArray(j.benefits)?j.benefits.map(String):[],travelRequired:Boolean(j.travel_required),interviewQuestions:Array.isArray(j.interview_questions)?j.interview_questions.map(String):[]});
const mapApplication=(a:any):AppRow=>({id:a.id,jobId:a.job_id,candidateId:a.candidate_id,status:a.status as Status,source:a.source??null,sourceDetail:a.source_detail??null,screeningAnswers:(a.screening_answers&&typeof a.screening_answers==='object')?a.screening_answers:undefined});
const mapEvent=(e:any):AppEvent=>({id:e.id,applicationId:e.application_id,fromStatus:(e.from_status??undefined) as Status|undefined,toStatus:e.to_status as Status,at:e.created_at,note:e.note??undefined});
const mapSavedJob=(x:any):SavedJob=>({id:x.id,candidateId:x.candidate_id,jobId:x.job_id,createdAt:x.created_at});
const mapJobAlert=(x:any):JobAlert=>({id:x.id,candidateId:x.candidate_id,name:x.name,cargo:x.cargo??null,skill:x.skill??null,city:x.city??null,minSalary:x.min_salary==null?null:Number(x.min_salary),maxSalary:x.max_salary==null?null:Number(x.max_salary),shift:x.shift??null,workModel:x.work_model??null,active:Boolean(x.active),createdAt:x.created_at,updatedAt:x.updated_at});
const mapMessage=(x:any):Message=>({id:x.id,applicationId:x.application_id,senderId:x.sender_id,recipientId:x.recipient_id,body:x.body,readAt:x.read_at??null,createdAt:x.created_at});
const mapInterview=(x:any):Interview=>({id:x.id,applicationId:x.application_id,scheduledAt:x.scheduled_at,durationMinutes:Number(x.duration_minutes??45),mode:x.mode==='presencial'?'presencial':'online',location:x.location??null,meetingUrl:x.meeting_url??null,interviewerId:x.interviewer_id??null,status:x.status as InterviewStatus,notes:x.notes??null,createdAt:x.created_at,updatedAt:x.updated_at});
const mapScorecard=(x:any):InterviewScorecard=>({id:x.id,applicationId:x.application_id,interviewerId:x.interviewer_id,competency:x.competency,rating:Number(x.rating??0),evidenceNote:x.evidence_note??null,createdAt:x.created_at});
const mapTalentPool=(x:any):TalentPool=>({id:x.id,companyId:x.company_id,name:x.name,description:x.description??null,createdBy:x.created_by,createdAt:x.created_at});
const mapTalentPoolMember=(x:any):TalentPoolMember=>({poolId:x.pool_id,candidateId:x.candidate_id,notes:x.notes??null,createdAt:x.created_at});
const mapOffer=(x:any):Offer=>({id:x.id,applicationId:x.application_id,salary:x.salary==null?null:Number(x.salary),startDate:x.start_date??null,message:x.message??null,status:x.status as OfferStatus,createdBy:x.created_by,respondedAt:x.responded_at??null,createdAt:x.created_at,updatedAt:x.updated_at});
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

export async function loadRemoteData(userId:string, role?:'empresa'|'candidato'|'admin'):Promise<DB>{
 if(!supabase)throw new Error('Supabase não configurado');
 const {data:members,error:memberError}=await supabase.from('company_members').select('company_id').eq('user_id',userId);
 if(memberError)throw memberError;
 const companyIds=(members??[]).map((x:any)=>x.company_id);
 const companyQuery=role==='admin'?supabase.from('companies').select('*'):companyIds.length?supabase.from('companies').select('*').in('id',companyIds):Promise.resolve({data:[],error:null} as any);
 const [companyRes,jobsRes,candidatesRes,appsRes,eventsRes,matchesRes,trainingRes,capabilityNodesRes,capabilityEdgesRes,outcomesRes,outcomeSkillSignalsRes,savedJobsRes,jobAlertsRes,messagesRes,interviewsRes,scorecardsRes,talentPoolsRes,talentPoolMembersRes,offersRes,notificationsRes,applicationNotesRes,jobEngagementEventsRes,candidateAvailabilityRes]=await Promise.all([
   companyQuery,
   supabase.from('jobs').select('*').order('created_at',{ascending:false}),
   (role==='candidato'?supabase.from('candidate_profiles').select('profile_id,display_name,role_title,years_experience,desired_salary,bio,city,searchable,candidate_skills(skill_id,proficiency,verified,years_experience,skills(name)),skill_evidence(id,skill_id,evidence_type,title,issuer,verified,verified_at,expires_at,score,storage_path,file_name,mime_type,file_size,file_hash,integrity_status,validation_status,reviewed_by,reviewed_at,review_note,skills(name)),talent_preferences(preferred_shifts)').eq('profile_id',userId):supabase.from('candidate_profiles').select('profile_id,display_name,role_title,years_experience,desired_salary,bio,city,searchable,candidate_skills(skill_id,proficiency,verified,years_experience,skills(name)),skill_evidence(id,skill_id,evidence_type,title,issuer,verified,verified_at,expires_at,score,storage_path,file_name,mime_type,file_size,validation_status,reviewed_by,reviewed_at,review_note,skills(name)),talent_preferences(preferred_shifts)').or(`searchable.eq.true,profile_id.eq.${userId}`)),
   supabase.from('applications').select('*').order('updated_at',{ascending:false}),
   supabase.from('application_events').select('*').order('created_at',{ascending:true}),
   supabase.from('matches').select('*').order('score',{ascending:false}),
   supabase.from('training_recommendations').select('id,candidate_id,job_id,skill_id,priority,reason,estimated_hours,status,gap_type,current_proficiency,target_proficiency,started_at,completed_at,updated_at,outcome_note,skills(name)').order('updated_at',{ascending:false}),
   supabase.from('capability_nodes').select('id,node_type,name,slug,skill_id,parent_id,description').order('node_type',{ascending:true}).order('name',{ascending:true}),
   supabase.from('capability_edges').select('from_node_id,to_node_id,relationship_type,weight,source').order('relationship_type',{ascending:true}),
   supabase.from('employment_outcomes').select('id,application_id,candidate_id,job_id,company_id,checkpoint,performance_score,ramp_up_days,retention_status,skill_feedback,manager_note,created_by,created_at,updated_at').order('created_at',{ascending:false}),
   supabase.from('employment_outcome_skill_signals').select('id,outcome_id,skill_id,capability_node_id,signal_status,manager_rating,training_needed,note,created_by,created_at,updated_at,skills(name)').order('created_at',{ascending:false}),
   supabase.from('saved_jobs').select('*').order('created_at',{ascending:false}),
   supabase.from('job_alerts').select('*').order('updated_at',{ascending:false}),
   supabase.from('messages').select('*').order('created_at',{ascending:true}),
   supabase.from('interviews').select('*').order('scheduled_at',{ascending:true}),
   supabase.from('interview_scorecards').select('*').order('created_at',{ascending:true}),
   supabase.from('talent_pools').select('*').order('created_at',{ascending:false}),
   supabase.from('talent_pool_members').select('*').order('created_at',{ascending:false}),
   supabase.from('offers').select('*').order('created_at',{ascending:false}),
   supabase.from('notifications').select('*').order('created_at',{ascending:false}),
   supabase.from('application_notes').select('*').order('created_at',{ascending:false}),
   supabase.from('job_engagement_events').select('*').order('created_at',{ascending:false}),
   supabase.from('candidate_availability').select('*').order('weekday',{ascending:true}).order('start_time',{ascending:true})
 ]);
 if(companyRes.error)throw companyRes.error;if(jobsRes.error)throw jobsRes.error;if(candidatesRes.error)throw candidatesRes.error;if(appsRes.error)throw appsRes.error;if(eventsRes.error)throw eventsRes.error;if(matchesRes.error)throw matchesRes.error;if(trainingRes.error)throw trainingRes.error;if(capabilityNodesRes.error)throw capabilityNodesRes.error;if(capabilityEdgesRes.error)throw capabilityEdgesRes.error;if(outcomesRes.error)throw outcomesRes.error;if(outcomeSkillSignalsRes.error)throw outcomeSkillSignalsRes.error;if(savedJobsRes.error)throw savedJobsRes.error;if(jobAlertsRes.error)throw jobAlertsRes.error;if(messagesRes.error)throw messagesRes.error;if(interviewsRes.error)throw interviewsRes.error;if(scorecardsRes.error)throw scorecardsRes.error;if(talentPoolsRes.error)throw talentPoolsRes.error;if(talentPoolMembersRes.error)throw talentPoolMembersRes.error;if(offersRes.error)throw offersRes.error;if(notificationsRes.error)throw notificationsRes.error;if(applicationNotesRes.error)throw applicationNotesRes.error;if(jobEngagementEventsRes.error)throw jobEngagementEventsRes.error;if(candidateAvailabilityRes.error)throw candidateAvailabilityRes.error;
 const jobIds=(jobsRes.data??[]).map((j:any)=>j.id);
 let jobSkills:any[]=[];
 if(jobIds.length){const r=await supabase.from('job_skills').select('job_id,skill_id,skills(name)').in('job_id',jobIds);if(r.error)throw r.error;jobSkills=r.data??[];}
 const jobs=(jobsRes.data??[]).map((j:any)=>({...mapJob(j),skills:jobSkills.filter(s=>s.job_id===j.id).map(s=>s.skills?.name).filter(Boolean)}));
 return {candidates:(candidatesRes.data??[]).map(mapCandidate),companies:(companyRes.data??[]).map(mapCompany),jobs,applications:(appsRes.data??[]).map(mapApplication),events:(eventsRes.data??[]).map(mapEvent),matches:(matchesRes.data??[]).map(mapMatch),training:(trainingRes.data??[]).map(mapTraining),capabilityNodes:(capabilityNodesRes.data??[]).map(mapCapabilityNode),capabilityEdges:(capabilityEdgesRes.data??[]).map(mapCapabilityEdge),outcomes:(outcomesRes.data??[]).map(mapOutcome),outcomeSkillSignals:(outcomeSkillSignalsRes.data??[]).map(mapOutcomeSkillSignal),savedJobs:(savedJobsRes.data??[]).map(mapSavedJob),jobAlerts:(jobAlertsRes.data??[]).map(mapJobAlert),messages:(messagesRes.data??[]).map(mapMessage),interviews:(interviewsRes.data??[]).map(mapInterview),scorecards:(scorecardsRes.data??[]).map(mapScorecard),talentPools:(talentPoolsRes.data??[]).map(mapTalentPool),talentPoolMembers:(talentPoolMembersRes.data??[]).map(mapTalentPoolMember),offers:(offersRes.data??[]).map(mapOffer),notifications:(notificationsRes.data??[]).map(mapNotification),applicationNotes:(applicationNotesRes.data??[]).map(mapApplicationNote),jobEngagementEvents:(jobEngagementEventsRes.data??[]).map(mapJobEngagementEvent),candidateAvailability:(candidateAvailabilityRes.data??[]).map(mapCandidateAvailability)};
}

async function findSkillIds(names:string[]):Promise<{id:string,name:string}[]>{
 if(!supabase||!names.length)return [];
 const {data,error}=await supabase.from('skills').select('id,name').in('name',names);
 if(error)throw error;return data??[];
}

export async function getRemoteBrazilCities():Promise<Array<{name:string;uf:string;ibgeCode:number}>>{
 if(!supabase)throw new Error('Supabase não configurado');
 const {data,error}=await supabase.from('brazil_cities').select('name,uf,ibge_code').order('name',{ascending:true}).order('uf',{ascending:true});
 if(error)throw error;
 return (data??[]).map((x:any)=>({name:String(x.name),uf:String(x.uf),ibgeCode:Number(x.ibge_code)}));
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

export async function createRemoteJob(userId:string,input:{title:string;description?:string;companyId:string;city:string;min:number;max:number;shift:string;skills:string[];screeningQuestions?:string[];employmentType?:string;workModel?:string;benefits?:string[];travelRequired?:boolean;interviewQuestions?:string[]}){
 if(!supabase)throw new Error('Supabase não configurado');
 const company=await supabase.from('companies').select('name').eq('id',input.companyId).single();if(company.error)throw company.error;
 const {data:job,error}=await supabase.from('jobs').insert({title:input.title,description:input.description?.trim()||null,company_id:input.companyId,company_public_name:company.data.name,city:input.city,salary_min:input.min,salary_max:input.max,shift:input.shift,status:'aberta',screening_questions:(input.screeningQuestions??[]).filter(Boolean),employment_type:input.employmentType||'CLT',work_model:input.workModel||'Presencial',benefits:(input.benefits??[]).filter(Boolean),travel_required:Boolean(input.travelRequired),interview_questions:(input.interviewQuestions??[]).filter(Boolean)}).select('*').single();
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
 const {error}=await supabase.rpc('update_application_status',{p_application_id:applicationId,p_status:status});
 if(error)throw error;
}

export async function applyToJob(userId:string,jobId:string,source='busca_vagas',sourceDetail?:string,screeningAnswers?:Record<string,string>){
 if(!supabase)throw new Error('Supabase não configurado');
 const {error}=await supabase.from('applications').insert({candidate_id:userId,job_id:jobId,status:'novo',source,source_detail:sourceDetail||null,screening_answers:screeningAnswers??{}});
 if(error)throw error;
}

export type Notification={id:string;userId:string;kind:string;title:string;body:string;href?:string|null;readAt?:string|null;createdAt:string};
export type ApplicationNote={id:string;applicationId:string;authorId:string;body:string;createdAt:string};
export type JobEngagementEvent={id:string;jobId:string;eventType:'visualizacao'|'inicio_candidatura';sessionId:string;candidateId?:string|null;createdAt:string};
export type CandidateAvailability={id:string;candidateId:string;weekday:number;startTime:string;endTime:string;active:boolean;createdAt:string};
const mapNotification=(x:any):Notification=>({id:x.id,userId:x.user_id,kind:x.kind,title:x.title,body:x.body,href:x.href??null,readAt:x.read_at??null,createdAt:x.created_at});
const mapApplicationNote=(x:any):ApplicationNote=>({id:x.id,applicationId:x.application_id,authorId:x.author_id,body:x.body,createdAt:x.created_at});
const mapCandidateAvailability=(x:any):CandidateAvailability=>({id:x.id,candidateId:x.candidate_id,weekday:Number(x.weekday),startTime:x.start_time,endTime:x.end_time,active:Boolean(x.active),createdAt:x.created_at});
const mapJobEngagementEvent=(x:any):JobEngagementEvent=>({id:x.id,jobId:x.job_id,eventType:x.event_type as 'visualizacao'|'inicio_candidatura',sessionId:x.session_id,candidateId:x.candidate_id??null,createdAt:x.created_at});
export async function saveRemoteJob(userId:string,jobId:string){if(!supabase)throw new Error('Supabase não configurado');const {error}=await supabase.from('saved_jobs').upsert({candidate_id:userId,job_id:jobId},{onConflict:'candidate_id,job_id'});if(error)throw error;}
export async function removeRemoteSavedJob(userId:string,jobId:string){if(!supabase)throw new Error('Supabase não configurado');const {error}=await supabase.from('saved_jobs').delete().eq('candidate_id',userId).eq('job_id',jobId);if(error)throw error;}
export async function createRemoteJobAlert(userId:string,input:{name:string;cargo?:string;skill?:string;city?:string;minSalary?:number;maxSalary?:number;shift?:string;workModel?:string}){if(!supabase)throw new Error('Supabase não configurado');const {error}=await supabase.from('job_alerts').insert({candidate_id:userId,name:input.name,cargo:input.cargo||null,skill:input.skill||null,city:input.city||null,min_salary:input.minSalary??null,max_salary:input.maxSalary??null,shift:input.shift||null,work_model:input.workModel||null});if(error)throw error;}
export async function toggleRemoteJobAlert(alertId:string,active:boolean){if(!supabase)throw new Error('Supabase não configurado');const {error}=await supabase.from('job_alerts').update({active,updated_at:new Date().toISOString()}).eq('id',alertId);if(error)throw error;}
export async function sendRemoteMessage(applicationId:string,senderId:string,recipientId:string,body:string){if(!supabase)throw new Error('Supabase não configurado');const {error}=await supabase.from('messages').insert({application_id:applicationId,sender_id:senderId,recipient_id:recipientId,body:body.trim()});if(error)throw error;}
export async function scheduleRemoteInterview(applicationId:string,scheduledAt:string,durationMinutes:number,mode:'online'|'presencial',location?:string,meetingUrl?:string){if(!supabase)throw new Error('Supabase não configurado');const user=(await supabase.auth.getUser()).data.user;const {data,error}=await supabase.from('interviews').insert({application_id:applicationId,scheduled_at:scheduledAt,duration_minutes:durationMinutes,mode,location:location||null,meeting_url:meetingUrl||null,interviewer_id:user?.id??null,status:'agendada'}).select('*').single();if(error)throw error;return mapInterview(data);}
export async function updateRemoteInterview(interviewId:string,status:InterviewStatus){if(!supabase)throw new Error('Supabase não configurado');const {error}=await supabase.from('interviews').update({status,updated_at:new Date().toISOString()}).eq('id',interviewId);if(error)throw error;}
export async function saveRemoteScorecard(applicationId:string,interviewerId:string,competency:string,rating:number,evidenceNote?:string){if(!supabase)throw new Error('Supabase não configurado');const {error}=await supabase.from('interview_scorecards').upsert({application_id:applicationId,interviewer_id:interviewerId,competency,rating,evidence_note:evidenceNote?.trim()||null},{onConflict:'application_id,interviewer_id,competency'});if(error)throw error;}
export async function createRemoteTalentPool(userId:string,companyId:string,name:string,description?:string){if(!supabase)throw new Error('Supabase não configurado');const {data,error}=await supabase.from('talent_pools').insert({company_id:companyId,name:name.trim(),description:description?.trim()||null,created_by:userId}).select('*').single();if(error)throw error;return mapTalentPool(data);}
export async function addRemoteTalentPoolMember(poolId:string,candidateId:string){if(!supabase)throw new Error('Supabase não configurado');const {error}=await supabase.from('talent_pool_members').upsert({pool_id:poolId,candidate_id:candidateId},{onConflict:'pool_id,candidate_id'});if(error)throw error;}
export async function createRemoteOffer(applicationId:string,createdBy:string,salary:number,startDate:string,message?:string){if(!supabase)throw new Error('Supabase não configurado');const {data,error}=await supabase.from('offers').upsert({application_id:applicationId,salary:Number.isFinite(salary)&&salary>0?salary:null,start_date:startDate||null,message:message?.trim()||null,status:'enviada',created_by:createdBy},{onConflict:'application_id'}).select('*').single();if(error)throw error;return mapOffer(data);}
export async function saveRemoteCandidateAvailability(candidateId:string,weekday:number,startTime:string,endTime:string){if(!supabase)throw new Error('Supabase não configurado');if(weekday<0||weekday>6||startTime>=endTime)throw new Error('Informe uma faixa de horário válida');const {error}=await supabase.from('candidate_availability').insert({candidate_id:candidateId,weekday,start_time:startTime,end_time:endTime,active:true});if(error)throw error;}
export async function removeRemoteCandidateAvailability(id:string){if(!supabase)throw new Error('Supabase não configurado');const {error}=await supabase.from('candidate_availability').delete().eq('id',id);if(error)throw error;}
export async function trackRemoteJobEngagement(jobId:string,eventType:'visualizacao'|'inicio_candidatura',sessionId:string,candidateId?:string){if(!supabase)throw new Error('Supabase não configurado');if(sessionId.length<16||sessionId.length>64)return;const {error}=await supabase.from('job_engagement_events').insert({job_id:jobId,event_type:eventType,session_id:sessionId,candidate_id:candidateId??null});if(error)throw error;}
export async function createRemoteApplicationNote(applicationId:string,authorId:string,body:string){if(!supabase)throw new Error('Supabase não configurado');const {data,error}=await supabase.from('application_notes').insert({application_id:applicationId,author_id:authorId,body:body.trim()}).select('*').single();if(error)throw error;return mapApplicationNote(data);}
export async function getRemoteApplicationContact(applicationId:string){if(!supabase)throw new Error('Supabase não configurado');const {data,error}=await supabase.rpc('get_application_contact',{p_application_id:applicationId});if(error)throw error;return data as string|null;}
export async function respondRemoteOfferSecure(offerId:string,status:'aceita'|'recusada'){if(!supabase)throw new Error('Supabase não configurado');const {data,error}=await supabase.rpc('respond_to_offer',{p_offer_id:offerId,p_status:status});if(error)throw error;return mapOffer(data);}
export async function respondRemoteInterviewSecure(interviewId:string,status:'confirmada'|'cancelada'){if(!supabase)throw new Error('Supabase não configurado');const {data,error}=await supabase.rpc('respond_to_interview',{p_interview_id:interviewId,p_status:status});if(error)throw error;return mapInterview(data);}
export async function markRemoteNotificationRead(notificationId:string){if(!supabase)throw new Error('Supabase não configurado');const {error}=await supabase.from('notifications').update({read_at:new Date().toISOString()}).eq('id',notificationId);if(error)throw error;}

export async function respondRemoteOffer(offerId:string,status:'aceita'|'recusada'){if(!supabase)throw new Error('Supabase não configurado');const {data,error}=await supabase.from('offers').update({status,responded_at:new Date().toISOString(),updated_at:new Date().toISOString()}).eq('id',offerId).select('*').single();if(error)throw error;return mapOffer(data);}
export async function getRemotePublicJobs():Promise<Job[]>{
 if(!supabase)throw new Error('Supabase não configurado');
 const {data,error}=await supabase.from('jobs').select('*').eq('status','aberta').order('created_at',{ascending:false});
 if(error)throw error;
 const rows=data??[];
 const ids=rows.map((x:any)=>x.id);
 let skills:any[]=[];
 if(ids.length){
  const res=await supabase.from('job_skills').select('job_id,skills(name)').in('job_id',ids).eq('required',true);
  if(res.error)throw res.error;
  skills=res.data??[];
 }
 return rows.map((row:any)=>({...mapJob(row),companyName:row.company_public_name??'Empresa',skills:skills.filter((x:any)=>x.job_id===row.id).map((x:any)=>x.skills?.name).filter(Boolean)}));
}

export async function getRemotePublicJob(slug:string){if(!supabase)throw new Error('Supabase não configurado');const {data,error}=await supabase.from('jobs').select('*,companies(name)').eq('public_slug',slug).eq('status','aberta').maybeSingle();if(error)throw error;if(!data)return null;const {data:skills,error:skillsError}=await supabase.from('job_skills').select('skills(name)').eq('job_id',data.id).eq('required',true);if(skillsError)throw skillsError;return {...mapJob(data),skills:(skills??[]).map((x:any)=>x.skills?.name).filter(Boolean),companyName:data.companies?.name??data.company_public_name??'Empresa'} as Job;}

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
 const hashBuffer=await crypto.subtle.digest('SHA-256',await file.arrayBuffer());const fileHash=Array.from(new Uint8Array(hashBuffer)).map(b=>b.toString(16).padStart(2,'0')).join('');const sameCandidate=await supabase.from('skill_evidence').select('id').eq('candidate_id',userId).eq('file_hash',fileHash).limit(1).maybeSingle();const safe=file.name.replace(/[^a-zA-Z0-9._-]/g,'_');
if(sameCandidate.error)throw sameCandidate.error;
 const duplicateOther=await supabase.from('skill_evidence').select('id').neq('candidate_id',userId).eq('file_hash',fileHash).limit(1).maybeSingle();if(duplicateOther.error)throw duplicateOther.error;if(sameCandidate.data)throw new Error('Este arquivo já foi enviado neste perfil');const integrityStatus=duplicateOther.data?'revisao':'normal';
 const storagePath=userId+'/'+skill.id+'/'+crypto.randomUUID()+'-'+safe;
 const upload=await supabase.storage.from('skill-evidence').upload(storagePath,file,{contentType:file.type||'application/octet-stream',upsert:false});
 if(upload.error)throw upload.error;
 const evidence=await supabase.from('skill_evidence').insert({
   candidate_id:userId,skill_id:skill.id,evidence_type:'certificado',title:file.name,issuer:'Enviado pelo profissional',
   verified:false,storage_path:storagePath,file_name:file.name,mime_type:file.type||null,file_size:file.size,file_hash:fileHash,integrity_status:integrityStatus
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
