# Back-end — Protótipo de aplicativo para contratação de profissionais autônomos

API REST em Node.js + Express, com PostgreSQL como banco de dados.

## Pré-requisitos

- Node.js e npm (já instalados nesta máquina)
- PostgreSQL instalado localmente, com um banco chamado `tcc_freelancers` criado

## Como rodar

1. Instale as dependências:
   ```
   npm install
   ```
2. Copie `.env.example` para `.env` e preencha `DATABASE_URL` com a senha do seu Postgres e um `JWT_SECRET` qualquer:
   ```
   cp .env.example .env
   ```
3. Rode o schema do banco (cria as tabelas). Só precisa fazer isso uma vez (ou de novo se o schema mudar):
   ```
   psql -U postgres -d tcc_freelancers -f src/db/schema.sql
   ```
4. Suba o servidor em modo desenvolvimento (reinicia sozinho a cada alteração):
   ```
   npm run dev
   ```
5. Confirme que está no ar:
   ```
   curl http://localhost:3000/health
   ```

## Endpoints

| Método | Rota                    | Auth                 | Descrição                                  |
|--------|-------------------------|-----------------------|---------------------------------------------|
| POST   | /auth/register           | não                    | Cria um usuário (`role`: cliente\|profissional) |
| POST   | /auth/login               | não                    | Autentica e retorna um JWT                  |
| GET    | /services                 | não                    | Lista serviços com status `aberto`          |
| GET    | /services/mine            | sim (role cliente)     | Lista os serviços publicados pelo usuário logado |
| POST   | /services                 | sim (role cliente)     | Publica um novo serviço                     |
| POST   | /services/:id/apply       | sim (role profissional)| Candidata o profissional logado a um serviço |

### Exemplo de fluxo via curl

```bash
# Cadastro como cliente
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Empresa X","email":"empresa@teste.com","password":"123456","role":"cliente"}'

# Login
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"empresa@teste.com","password":"123456"}'

# Criar serviço (troque SEU_TOKEN pelo token retornado no login/registro)
curl -X POST http://localhost:3000/services \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer SEU_TOKEN" \
  -d '{"title":"Pintura de fachada","description":"Pintar a fachada de uma loja","budget":800}'
```
