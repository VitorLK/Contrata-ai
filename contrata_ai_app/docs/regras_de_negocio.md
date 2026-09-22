# Regras de negócio — Contrata Aí

Este documento descreve as regras vigentes para perfis, descoberta, contratação e jornada. Ele deve evoluir junto com o aplicativo e servir como referência para implementação, testes e texto do TCC.

## 1. Papéis da plataforma

- **Contratante:** publica serviços, consulta profissionais, analisa candidaturas, contrata e avalia.
- **Profissional:** mantém uma vitrine pública, busca serviços, envia candidaturas e acompanha seu desempenho.
- Uma conta possui somente um papel nesta versão. Troca de papel e conta híbrida ficam fora do escopo atual.

## 2. Perfil profissional

Para salvar o perfil, o profissional deve informar:

- uma apresentação com no mínimo 60 caracteres;
- entre 1 e 6 áreas de atuação;
- UF e município;
- forma de atendimento: presencial, remoto ou híbrido;
- disponibilidade: disponível agora, nesta semana, nas próximas semanas ou somente com agendamento.

O valor por hora é opcional, mas, quando informado, deve ser maior que zero. Foto, experiência, telefone e portfólio aumentam a força do perfil, mas não impedem o cadastro inicial.

As áreas exibidas como filtro pertencem a um catálogo controlado. Especialidades fora do catálogo podem ser adicionadas ao perfil e continuam pesquisáveis pelo campo de texto, sem criar filtros duplicados por diferenças de grafia.

## 3. Localização

- O usuário escolhe primeiro a UF e depois um município pertencente a ela.
- A lista de municípios vem da API de Localidades do IBGE e é armazenada em cache no dispositivo.
- Alterar a UF limpa o município selecionado.
- Na busca, UF e município são opcionais. No perfil profissional, ambos são obrigatórios.
- O back-end usa comparação exata de UF e município para evitar resultados incorretos por nomes parciais.

## 4. Busca de profissionais

O contratante pode combinar:

- texto livre, aplicado a nome, apresentação e habilidades;
- área de atuação;
- UF e município;
- uma ou mais formas de atendimento;
- disponibilidade imediata;
- valor máximo por hora;
- ordenação.

Quando um valor máximo é aplicado, profissionais sem valor informado não entram no resultado, pois não é possível afirmar que atendem ao orçamento.

### Ordenação recomendada

1. profissionais disponíveis agora;
2. maior média de avaliações;
3. maior quantidade de áreas informadas;
4. nome em ordem alfabética como desempate.

O contratante também pode ordenar por avaliação, menor valor, maior valor ou nome. Perfis sem avaliação aparecem depois dos avaliados quando esse critério é escolhido.

## 5. Avaliação

- Uma avaliação só pode ser enviada pelo contratante responsável pelo serviço.
- O serviço precisa estar concluído.
- O profissional avaliado deve ser o profissional contratado para aquele serviço.
- Existe no máximo uma avaliação por serviço e contratante.
- A busca recebe do back-end a média e o total de avaliações; o front-end não recalcula esses valores.

## 6. Fluxo de contratação atual

1. O contratante publica um serviço com profissão, data, modalidade, local aplicável e valor fixo opcional.
2. Profissionais enviam candidaturas.
3. O contratante aceita uma candidatura; as demais são recusadas.
4. O serviço passa para “em andamento”.
5. Na data combinada, o profissional inicia a jornada pelo ponto digital.
6. Ao finalizar, o profissional pode registrar observação e foto de ocorrência.
7. A jornada é enviada para confirmação do contratante ou confirmada automaticamente, conforme a preferência dele.
8. A confirmação conclui o serviço, libera o comprovante e contabiliza horas e valores no desempenho.
9. Após a conclusão, o contratante pode avaliar o profissional.

## 7. Descoberta e validade das oportunidades

- A busca do profissional abre inicialmente em “Hoje” e “Abertos”.
- É possível filtrar por texto, profissão, status, período, modalidade, UF, município e faixa de valor.
- Os períodos disponíveis são hoje, próximos e todas as datas.
- Os status de descoberta são abertos, fechados e todos. “Fechados” agrupa concluídos e cancelados.
- Um serviço aberto cuja data passou fica oculto da descoberta e bloqueado para novas candidaturas.
- O contratante continua vendo o anúncio vencido em “Meus serviços” e pode escolher “Manter aberto”.
- A renovação registra uma confirmação para o dia atual e preserva as candidaturas anteriores.

## 8. Jornada e cálculo do valor

- Somente o profissional aceito pode iniciar a jornada.
- A jornada não pode ser iniciada antes da data agendada.
- Um profissional pode manter somente uma jornada em andamento por vez.
- Cada serviço possui no máximo uma jornada nesta versão do protótipo.
- O horário inicial e o horário final são definidos pelo servidor; fechar ou recarregar o aplicativo não zera o cronômetro.
- Ao iniciar, o sistema cria uma cópia do valor por hora do perfil e do valor fixo do serviço. Alterações futuras não modificam o histórico.
- Se o profissional possui valor por hora, o total é `minutos trabalhados / 60 × valor por hora`.
- Se não possui valor por hora, é usado o valor fixo informado no serviço.
- Quando nenhum dos dois valores existe, o início é bloqueado até que uma das partes informe a base de cálculo.
- O tempo é arredondado para o próximo minuto, com mínimo de um minuto.

## 9. Confirmação e notificações

- A preferência “Confirmar jornada antes de concluir” pertence ao contratante e vem ativada por padrão.
- Quando ativa, a jornada finalizada fica aguardando confirmação e o serviço permanece em andamento.
- Quando desativada, a jornada é confirmada e o serviço é concluído automaticamente; o contratante ainda recebe uma notificação informativa.
- A Central de trabalho exibe notificações internas e os detalhes necessários à confirmação: profissional, serviço, início, fim, duração, valor, observação e foto, quando houver.
- Horas e valores entram no desempenho somente depois da confirmação manual ou automática.

## 10. Meu desempenho e comprovante

- O resumo semanal informa quantidade de serviços confirmados, horas trabalhadas e total arrecadado.
- O gráfico mensal agrega o valor confirmado por dia e permite navegar entre meses passados.
- O histórico conserva os valores usados no cálculo e permite abrir o comprovante do serviço.
- O comprovante contém número de controle, serviço, categoria, contratante, profissional, data, horários, duração, forma de cálculo, valor, observação, evidência e data de confirmação.
- O documento emitido pelo protótipo é um **comprovante não fiscal**. Ele não substitui NFS-e, recibo tributário ou obrigação legal aplicável.

## 11. Decisões necessárias para a próxima etapa

As regras abaixo ainda não estão implementadas e precisam ser confirmadas antes de ampliar o banco:

1. **Solicitação direta:** permitir que o contratante convide um profissional encontrado na busca ou manter apenas o fluxo público de candidaturas.
2. **Endereço detalhado:** decidir quando liberar bairro, rua e ponto de referência sem expor o endereço antes da contratação.
3. **Privacidade do telefone:** decidir se o contato fica público ou é liberado somente após a contratação.
4. **Raio de atendimento:** definir distância máxima para trabalhos presenciais e como calculá-la.
5. **Agenda estruturada:** substituir disponibilidade resumida por dias da semana, turnos e data mais próxima.
6. **Contestação:** criar prazo, motivo, evidências e fluxo de mediação quando o contratante discordar da jornada.
7. **Vários dias:** decidir se um mesmo serviço poderá possuir diversas jornadas.
8. **Documento fiscal:** definir se haverá integração com NFS-e e quais municípios/provedores serão suportados.
9. **Verificação:** definir critérios e documentos para um selo de identidade ou qualificação profissional.

Esses itens devem virar histórias de usuário e critérios de aceite antes da próxima implementação.
