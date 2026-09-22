# Contrata Aí

Aplicativo Flutter com arquitetura MVVM para conectar contratantes e profissionais autônomos. A API REST fica na pasta irmã `backend` e usa Node.js, Express e PostgreSQL.

## Como rodar

Abra dois terminais.

### 1. Back-end

```powershell
cd C:\Users\Desktop\Desktop\Tcc\backend
npm install
npm run migrate
npm start
```

O arquivo de configuração local é `C:\Users\Desktop\Desktop\Tcc\backend\.env`. Use `.env.example` como referência e não publique a senha do PostgreSQL.

### 2. Aplicativo web

```powershell
cd C:\Users\Desktop\Desktop\Tcc\flutter_application_1
flutter pub get
flutter run -d web-server --web-port 8080
```

Depois, abra `http://localhost:8080`.

Para Android, com um emulador ou aparelho conectado:

```powershell
flutter run
```

## Contas de demonstração

Para preparar dados que exercitam as telas de jornada, confirmação, desempenho e comprovante:

```powershell
cd C:\Users\Desktop\Desktop\Tcc\backend
npm run seed:demo
```

- Contratante: `cliente.demo@contrata.local` / `demo123`
- Profissional: `profissional.demo@contrata.local` / `demo123`

O seed altera somente registros identificados como demonstração.

## Verificações

```powershell
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

O teste ponta a ponta do backend cria dados temporários e os remove ao terminar:

```powershell
cd C:\Users\Desktop\Desktop\Tcc\backend
npm run smoke:workflow
```

As regras de negócio implementadas estão documentadas em [docs/regras_de_negocio.md](docs/regras_de_negocio.md).
