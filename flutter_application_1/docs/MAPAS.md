# Mapas e localização

O aplicativo usa `flutter_map` para exibir mapas do OpenStreetMap. A busca
textual passa pelo backend em `GET /locations/geocode`, que consulta o
Nominatim somente quando o usuário pressiona **Localizar no mapa**.

## Fluxo

1. O contratante escolhe UF e cidade e informa bairro ou referência.
2. **Localizar no mapa** converte o texto em latitude e longitude.
3. O marcador pode ser corrigido com um toque no mapa.
4. As coordenadas são salvas no serviço e exibidas no detalhe.
5. **Abrir rota no Google Maps** usa as coordenadas salvas.

## Desenvolvimento e produção

- O servidor público do Nominatim aceita no máximo uma requisição por segundo
  e não permite autocomplete. O backend serializa as requisições e mantém cache
  em memória por 24 horas.
- Os tiles públicos do OpenStreetMap exigem atribuição visível e não permitem
  download em massa/offline. A atribuição permanece dentro do mapa.
- Para produção com tráfego real, configure `GEOCODING_URL` e `MAP_USER_AGENT`
  no `backend/.env` para um provedor com SLA ou uma instância própria.
- O provedor de tiles pode ser trocado sem editar código:

  ```powershell
  flutter run -d chrome --dart-define="MAP_TILE_URL=https://seu-provedor/{z}/{x}/{y}.png"
  ```

## Windows: suporte a plugins

Se o Flutter pedir suporte a links simbólicos:

1. Abra **Configurações** do Windows.
2. Entre em **Sistema > Para desenvolvedores**.
3. Ative **Modo de Desenvolvedor**.
4. Feche e abra novamente o terminal.
5. Execute `flutter pub get`.
