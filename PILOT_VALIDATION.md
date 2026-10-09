# TalentOS — validação técnica de 09/10/2026

## Aplicado e comprovado em produção

- Migração de integridade dos comprovantes da PR #71 aplicada ao Supabase.
- Upload real de um comprovante privado: substituição bloqueada, exclusão com referência bloqueada, bytes preservados e referência a arquivo inexistente recusada.
- Conta técnica cadastrada, confirmação recebida, login com senha validado.
- Recuperação recebida, sessão de recuperação validada e troca de senha da conta técnica testada pela API.
- Currículo manual salvo e relido; candidato não enxerga outros candidatos nem consegue elevar seu papel para administrador.
- Exportação dos próprios dados validada; dados privados não expostos a acesso anônimo; endpoint da equipe exige autenticação.
- Testes SQL de RLS, permissões de equipe, revisão/desenvolvimento/matching e acompanhamento 30/60/90 dias passaram.

Os testes SQL de fluxo usam dados fictícios em transações encerradas com ROLLBACK. Não representam testes completos da interface nem autorização para alterar dados de clientes.

## Correções nesta revisão (aguardam aprovação/publicação)

1. Convites: expressão regular rejeitava e-mails normais. Validador isolado e teste de regressão.
2. Mensagens do candidato: a política consultava membros da empresa sob RLS que oculta esses registros do candidato. Helper privado retorna somente autorização booleana, vinculada ao remetente autenticado, candidatura e destinatário. A tabela de membros continua privada.
3. PDF: preservar quebras de linha da extração e normalizar espaços nos trechos de competências.
4. Atualizar testes SQL antigos para as restrições atuais: desafio pontuado forjado deve ser recusado, origem de competência é imutável e RPCs antigos de equipe não existem.
5. Novo teste transacional de vaga → candidatura → mensagem → entrevista → proposta → contratação; inclui isolamento entre empresas/candidatos, observador sem poder de alteração e transferência de proprietário.

Validação local: compilação aprovada e 16 testes Node aprovados. O novo teste de recrutamento passou com a migração de mensagens aplicada apenas dentro da transação de teste e revertida ao final. A migração nova NÃO está aplicada permanentemente.

## Bloqueios reais — não declarar o piloto concluído

- Os links reais de confirmação e recuperação emitidos pelo Supabase redirecionaram para `http://localhost:3000/`, apesar do pedido de retorno à URL oficial. Ajustar Site URL e lista permitida no painel do projeto. O painel exige autenticação do proprietário.
- Após dois e-mails, o cadastro da segunda conta técnica retornou `email rate limit exceeded`. O envio padrão não serve como comprovação de capacidade para um piloto com várias pessoas. Configurar serviço SMTP apropriado, mantendo custo zero e aprovação de qualquer conta/domínio/credencial necessários.
- Proteção nativa contra senhas vazadas indisponível no plano Free; o Supabase exige Pro ou superior. Nenhum upgrade foi contratado.
- A execução de navegador local não estava disponível; a navegação pública foi conferida no navegador conectado. Os fluxos autenticados foram exercitados por API/SQL, não homologados integralmente pela interface.
- Não foram contornadas as permissões da Vercel nem feitas publicações de código novo sem a revisão humana.

## Publicação após revisão humana

1. Revisar e integrar esta PR.
2. Aplicar `candidate_message_authorization` no projeto `kvxqhvngkjxqlvlzcsef` e executar `supabase/tests/recruiting_journey.sql`.
3. Publicar `company-team` incluindo `index.ts`, `validation.ts` e `deno.json`, preservando verificação JWT.
4. Confirmar o deploy Vercel da revisão integrada.
5. Ajustar autenticação e envio de e-mail; repetir confirmação, recuperação e convite desde uma caixa de testes.
6. Homologar a interface com candidato e empresa, sem alterar dados de usuários reais.

URL oficial: https://talentos-industrial.vercel.app
