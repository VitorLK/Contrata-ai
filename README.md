# Contrata Aí

O **Contrata Aí** é uma plataforma para aproximar pessoas e empresas que precisam contratar um serviço de profissionais disponíveis para realizá-lo. O projeto nasceu como Trabalho de Conclusão de Curso e evoluiu para um protótipo funcional, com aplicativo responsivo, API própria e regras de negócio que acompanham todo o processo: da publicação da oportunidade à conclusão e avaliação do trabalho.

Mais do que uma vitrine de profissionais, a proposta é organizar uma relação que normalmente acontece de forma dispersa. Contratante e profissional conseguem combinar o serviço, acompanhar a jornada, registrar ocorrências e manter um histórico do que foi realizado dentro da mesma plataforma.

## O que o projeto oferece

### Para quem contrata

- cadastro e autenticação de contratantes;
- publicação, edição, renovação e cancelamento de serviços;
- imagem de apresentação, categoria, orçamento, data e localização do serviço;
- visualização do endereço em mapa;
- busca de profissionais por nome, área, localização, avaliação, disponibilidade e forma de cobrança;
- análise e aceite de candidaturas;
- conversa direta com profissionais e envio de propostas;
- acompanhamento do início e do encerramento do trabalho;
- confirmação manual ou automática da jornada;
- avaliação do profissional após a conclusão;
- central de notificações e histórico dos serviços.

### Para quem presta serviços

- perfil profissional com foto, apresentação, experiência, especialidades e portfólio;
- definição de atendimento presencial, remoto ou híbrido;
- cobrança por hora ou por empreitada;
- agenda semanal com períodos de disponibilidade;
- busca de oportunidades com filtros de profissão, data, situação, modalidade, localização e valor;
- candidatura e cancelamento de candidatura;
- recebimento e resposta de propostas pelo chat;
- controle da jornada com início, cronômetro e finalização;
- registro de observação e foto de ocorrência;
- painel de desempenho com serviços realizados, horas trabalhadas e valores recebidos;
- emissão de comprovante não fiscal do serviço.

### Para a administração

- visão geral da plataforma;
- acompanhamento de usuários, profissionais, empresas e serviços;
- atualização e exclusão de registros administrativos;
- indicadores de utilização;
- histórico de auditoria das ações realizadas no painel.

## Como funciona

O fluxo mais comum começa quando um contratante publica uma oportunidade. Os profissionais podem encontrá-la pelos filtros e enviar uma candidatura. Depois que uma candidatura é aceita, o serviço entra na agenda do profissional e as demais candidaturas são encerradas.

No dia combinado, o profissional inicia a jornada pelo aplicativo. O horário é registrado pelo servidor, portanto o cronômetro não depende de a tela permanecer aberta. Ao finalizar, é possível acrescentar uma observação e uma foto. Conforme a preferência do contratante, o trabalho é confirmado imediatamente ou fica aguardando conferência.

Somente depois da confirmação as horas e o valor entram no painel de desempenho. O contratante também recebe a opção de avaliar o profissional, fechando o ciclo do serviço.

O sistema ainda permite uma contratação mais direta: o contratante encontra um profissional, inicia uma conversa e envia uma proposta com data e horário. A agenda impede o aceite de períodos conflitantes, inclusive quando um trabalho atravessa a meia-noite.

## Tecnologias utilizadas

| Camada | Tecnologias |
| --- | --- |
| Aplicativo | Flutter e Dart |
| Arquitetura do aplicativo | MVVM com Provider |
| Comunicação | API REST com HTTP e autenticação JWT |
| Back-end | Node.js e Express |
| Banco de dados | PostgreSQL |
| Mapas e geocodificação | OpenStreetMap, Flutter Map e Nominatim |
| Localidades | API de Localidades do IBGE |
| Imagens | Upload multipart com Multer |
| Demonstração remota | Cloudflare Quick Tunnel |

## Organização do repositório

```text
Contrata-ai/
├── backend/                 # API REST, banco, migrações e uploads
│   ├── src/controllers/     # Regras dos endpoints
│   ├── src/routes/          # Rotas da API
│   ├── src/db/              # Schema, migrações, seeds e testes de fluxo
│   └── uploads/             # Imagens enviadas durante o uso local
├── contrata_ai_app/         # Aplicativo Flutter
│   ├── lib/models/          # Modelos de domínio
│   ├── lib/services/        # Repositórios e acesso à API
│   ├── lib/viewmodels/      # Estado e regras de apresentação
│   ├── lib/views/           # Telas do aplicativo
│   ├── lib/widgets/         # Componentes reutilizáveis
│   ├── docs/                # Regras de negócio e decisões do projeto
│   └── test/                # Testes automatizados do Flutter
└── README.md
```

No aplicativo, as telas não acessam a API diretamente. As `Views` observam seus `ViewModels`, que coordenam os modelos e os repositórios responsáveis pela comunicação com o back-end. Essa separação mantém a interface desacoplada das regras de negócio e facilita testes e futuras alterações.

## Como executar localmente

### Pré-requisitos

Antes de começar, instale:

- Flutter com uma versão compatível com Dart 3.13 ou superior;
- Node.js e npm;
- PostgreSQL;
- Google Chrome para executar a versão web;
- Android Studio, um emulador ou um aparelho Android, caso queira testar a versão móvel.

Clone o repositório e entre na pasta do projeto:

```powershell
git clone https://github.com/VitorLK/Contrata-ai.git
cd Contrata-ai
```

### 1. Configure o banco e o back-end

Entre na pasta do servidor e instale as dependências:

```powershell
cd backend
npm install
```

Crie no PostgreSQL um banco chamado `tcc_freelancers`. Isso pode ser feito pelo pgAdmin ou, se as ferramentas do PostgreSQL estiverem disponíveis no terminal, pelo comando:

```powershell
createdb -U postgres tcc_freelancers
```

Crie o arquivo local de configuração a partir do exemplo:

```powershell
Copy-Item .env.example .env
```

Abra `backend/.env` e informe a conexão com o PostgreSQL e uma chave JWT própria:

```env
PORT=3000
DATABASE_URL=postgresql://postgres:SUA_SENHA@localhost:5432/tcc_freelancers
JWT_SECRET=troque_por_um_segredo_forte
GEOCODING_URL=https://nominatim.openstreetmap.org/search
MAP_USER_AGENT=ContrataAi-TCC/1.0 (academic service marketplace)
```

O arquivo `.env` contém dados sensíveis e já está configurado para não ser enviado ao Git.

Com o banco criado, aplique o schema inicial e as migrações:

```powershell
psql -U postgres -d tcc_freelancers -f src/db/schema.sql
npm run migrate
```

Por fim, inicie a API:

```powershell
npm run dev
```

Ela ficará disponível em `http://localhost:3000`. Para confirmar que o servidor está respondendo, acesse `http://localhost:3000/health` ou execute:

```powershell
Invoke-RestMethod http://localhost:3000/health
```

### 2. Execute o aplicativo Flutter

Em outro terminal, aberto na raiz do repositório:

```powershell
cd contrata_ai_app
flutter pub get
flutter run -d chrome
```

Também é possível iniciar um servidor web em uma porta fixa:

```powershell
flutter run -d web-server --web-port 8080
```

Nesse caso, abra `http://localhost:8080` no navegador.

### Android

Com um emulador Android aberto, execute dentro de `contrata_ai_app`:

```powershell
flutter run
```

O aplicativo reconhece o emulador Android e usa `10.0.2.2` para alcançar a API do computador. Em um aparelho físico conectado à mesma rede, informe o IP local do computador:

```powershell
flutter run --dart-define=API_BASE_URL=http://IP_DO_COMPUTADOR:3000
```

O firewall do Windows precisa permitir a conexão com a porta `3000` para que esse modo funcione.

## Dados de demonstração

O projeto possui um seed com usuários, perfis e serviços preparados para apresentar os principais fluxos. Com a API configurada, execute a partir da raiz do repositório:

```powershell
cd backend
npm run seed:demo
```

As contas criadas são:

| Perfil | E-mail | Senha |
| --- | --- | --- |
| Contratante | `cliente.demo@contrata.local` | `demo123` |
| Profissional por hora | `profissional.demo@contrata.local` | `demo123` |
| Profissional por empreitada | `empreitada.demo@contrata.local` | `demo123` |
| Administrador | `admin@contrata.local` | `demo123` |

Essas credenciais existem somente para desenvolvimento e demonstração. Elas não devem ser reutilizadas em um ambiente real.

## Teste pelo celular fora da rede local

Para apresentações, o projeto inclui um script que compila o Flutter Web, inicia a API e cria um endereço HTTPS temporário pelo Cloudflare Quick Tunnel.

Na pasta `contrata_ai_app`, execute:

```powershell
.\iniciar-demo.ps1
```

Também é possível abrir `iniciar-demo.cmd` com dois cliques. Quando o terminal exibir a URL `https://...trycloudflare.com`, ela poderá ser acessada pelo celular, inclusive em outra rede.

O computador, o PostgreSQL e o terminal precisam permanecer ligados durante a demonstração. Ao pressionar `Ctrl+C`, o endereço deixa de funcionar, mas os dados locais são preservados.

## Verificações e testes

Para verificar o aplicativo, partindo da raiz do repositório:

```powershell
cd contrata_ai_app
flutter analyze
flutter test
flutter build web
```

Para testar os principais fluxos da API, também a partir da raiz:

```powershell
cd backend
npm run smoke:workflow
npm run smoke:scheduling
```

Os testes de fluxo utilizam o banco configurado no `.env`, criam registros temporários e fazem a limpeza ao terminar.

## Principais grupos da API

| Caminho | Responsabilidade |
| --- | --- |
| `/auth` | cadastro e autenticação |
| `/services` | serviços, candidaturas, aceite, conclusão e avaliação |
| `/applications` | candidaturas do profissional |
| `/professionals` | perfil, portfólio, agenda e busca de profissionais |
| `/work` | jornada, desempenho, comprovantes e notificações |
| `/chat` | conversas, mensagens e propostas |
| `/locations` | busca de endereços e coordenadas |
| `/admin` | indicadores e operações administrativas |

As rotas protegidas recebem o token JWT no cabeçalho `Authorization: Bearer <token>`.

## Limites atuais do protótipo

O Contrata Aí ainda é um projeto acadêmico em evolução. Alguns pontos foram mantidos simples de propósito:

- as imagens são armazenadas no próprio servidor;
- o banco utilizado na demonstração é local;
- o túnel público é temporário e voltado apenas a testes;
- o comprovante emitido não possui valor fiscal;
- ainda não existe processamento de pagamentos dentro da plataforma;
- recursos como contestação de jornada, verificação documental e serviços com várias jornadas podem ser desenvolvidos em etapas futuras.

Essas limitações não impedem a demonstração do fluxo principal, mas precisam ser revistas antes de uma publicação em produção.

## Documentação complementar

- [Regras de negócio](contrata_ai_app/docs/regras_de_negocio.md)
- [Decisões sobre mapas e localização](contrata_ai_app/docs/MAPAS.md)
- [Estratégia da landing page](contrata_ai_app/docs/landing_page_estrategia.md)
- [Demonstração remota](contrata_ai_app/DEMONSTRACAO_REMOTA.md)
- [Documentação do back-end](backend/README.md)

---

Este repositório registra a construção de um TCC e, ao mesmo tempo, a tentativa de resolver um problema bastante cotidiano: tornar a contratação de serviços mais clara, organizada e segura para os dois lados.
