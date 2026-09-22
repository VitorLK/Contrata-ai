# Demonstração remota

O modo de demonstração publica temporariamente a versão Web do Contrata Aí e a
API local em uma única URL HTTPS. O PostgreSQL e os uploads continuam no
computador; nenhum dado é migrado ou apagado.

## Iniciar

Use uma destas opções:

- dê dois cliques em `iniciar-demo.cmd`; ou
- no PowerShell desta pasta, execute `./iniciar-demo.ps1`.

A compilação pode levar alguns segundos. Quando o terminal mostrar `Your quick
Tunnel has been created`, abra no celular a URL `https://...trycloudflare.com`.
O celular pode estar em outra rede ou usando internet móvel.

## Encerrar

Pressione `Ctrl+C` no terminal. O link deixa de funcionar, mas os dados
continuam no PostgreSQL e as imagens continuam em `backend/uploads`.

## Limitações

- O computador, o PostgreSQL e a janela do terminal precisam permanecer
  ligados.
- Uma nova URL é criada a cada execução.
- O túnel é indicado somente para testes e apresentações. Use contas e dados
  fictícios.
