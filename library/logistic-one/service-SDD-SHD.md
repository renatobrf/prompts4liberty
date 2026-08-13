# Serviço de Same Day Delivery e Same Hour Delivery

## Visão geral

Este serviço foi pensado para atender uma operação logística urbana altamente sensível ao tempo em uma região metropolitana, com foco em entregas rápidas para consumidores finais e clientes corporativos. A proposta combina estoques físicos de grande porte posicionados fora da cidade com micro-estoques regionais de pequeno porte em lojas físicas de varejo dentro da área urbana, permitindo reduzir tempo de ciclo, melhorar o nível de serviço e aumentar a disponibilidade de itens em regiões densamente atendidas.

A operação é estruturada para atender dois modelos de serviço:

- Same Day Delivery (SDD): entrega no mesmo dia, com janela de atendimento até o fim do dia útil.
- Same Hour Delivery (SHD): entrega em até 1 hora, geralmente em áreas urbanas prioritárias e com foco em itens de alta demanda, urgência ou melhor índice de conversão.

A arquitetura operacional considera a segregação entre estoque de abastecimento e estoque de atendimento local, com regras de priorização por proximidade, SLA, disponibilidade e custo.

## Contexto operacional

A operação logística da região metropolitana é composta por:

- Armazéns centrais ou regionais fora da cidade, de grande porte, com maior capacidade e melhor custo por unidade.
- Estoques regionais de pequeno porte, instalados em lojas de varejo ou hubs urbanos, próximos ao cliente.
- Rede de clientes locais em alta densidade territorial.
- Canal omnichannel, que integra e-commerce, lojas físicas, marketplaces e clientes corporativos.

Esse modelo permite que a empresa opere com:

- melhor capacidade de abastecimento,
- menor risco de ruptura em itens de alto volume,
- melhor tempo de entrega para regiões urbanas densas,
- maior flexibilidade para atender pedidos emergenciais e eventos de pico.

## Objetivos do serviço

### Objetivos principais

- Entregar pedidos em até 24 horas em áreas metropolitanas e em até 1 hora em áreas prioritárias.
- Reduzir a distância percorrida do produto até o cliente final.
- Melhorar a capacidade de atendimento em horários de pico e promoções.
- Equilibrar custo logístico, disponibilidade de estoque e nível de serviço.
- Usar estoques locais para reduzir tempo de ciclo sem depender exclusivamente de grandes centros externos.

### Indicadores de sucesso

- Taxa de atendimento de pedidos no mesmo dia.
- Tempo médio de processamento do pedido até a entrega.
- Cobertura de SKUs em hubs urbanos e lojas.
- Taxa de cancelamento por indisponibilidade.
- Percentual de pedidos atendidos por loja local versus hub externo.
- Custo por entrega e custo logístico por pedido.
- Taxa de entrega no prazo em SHD/SDD.

## Modelo de operação

### 1. Estoque fora da cidade

Os armazéns externos atuam como base de abastecimento e de consolidação. Neles ficam os itens de maior volume, maior variedade e maior rotação logística.

Funções principais:

- receber mercadorias e consolidar estoque de entrada;
- executar picking em lote por pedido ou por região;
- preparar cargas para distribuição regional;
- abastecer lojas e hubs urbanos;
- atuar como rede de ressuprimento para itens de baixa disponibilidade local.

### 2. Estoques regionais em lojas físicas

As lojas físicas dentro da cidade funcionam como pontos de atendimento regional e micro-fulfillment, com estoques mais enxutos, porém muito próximos ao cliente.

Funções principais:

- atender pedidos de gatilho local e de grande urgência;
- permitir pick-up e entrega em mesmo dia/hora;
- reduzir tempos de deslocamento e evitar filas de transporte longo;
- servir como pontos de distribuição para zonas de alta densidade.

Esses estoques precisam ser geridos com regras de reserva e prioridade para evitar conflitos entre venda ao consumidor, consumo interno da loja e operação de entrega rápida.

## Estratégia de atendimento

### Roteiro de decisão de origem do pedido

Cada pedido deve passar por uma regra de elegibilidade e alocação, tomando como base:

- localização do cliente;
- SLA exigido (SDD ou SHD);
- disponibilidade do SKU;
- tempo estimado de saída e entrega;
- preço de transporte;
- status do estoque local;
- saturação do hub urbano ou da loja.

### Regras de priorização

1. Se o item estiver disponível em uma loja ou hub urbano próximo ao cliente e a janela de atendimento suportar o SLA, priorizar a origem local.
2. Se o item estiver indisponível localmente, buscar no centro externo com prioridade de envio de bike, van ou motoristas locais.
3. Para SHD, priorizar micro-centros e lojas com alta capacidade de resposta e menor distância de entrega.
4. Para SDD, priorizar a combinação melhor custo/tempo entre origem local e origem externa.

### Custo e SLA em equilíbrio

A operação deve considerar uma métrica de decisão por pedido, combinando:

- tempo de entrega;
- probabilidade de sucesso;
- custo de operação local versus externa;
- disponibilidade do item.

Em geral, o SHD exige menor margem de erro e maior acurácia de estoque e tempo de processamento, enquanto o SDD aceita mais latitude operacional, com foco em eficiência e volume.

## Fluxo operacional proposto

### 1. Recepção do pedido

O pedido entra em um sistema de order management ou serviço de orquestração, que identifica:

- canal de origem (e-commerce, app, loja, marketplace);
- local de entrega;
- SLA solicitado;
- SKU e quantidade;
- regras de promoção ou logística.

### 2. Alocação do estoque

O serviço executa a logística de alocação com base em:

- estoque disponível local;
- estoque em hubs urbanos;
- estoque em armazém central;
- capacidade atual de picking e packing;
- previsão de atendimento em período crítico.

### 3. Picking e preparação

Dependendo da origem escolhida:

- loja ou hub urbano executa picking local;
- armazém externo executa picking e consolidação para envio;
- carregamento é organizado por rota, zona e tipo de entrega.

### 4. Expedição

A retirada do pedido pode acontecer por:

- motociclista em SHD;
- van ou carro de entrega em SDD;
- cross-dock de rota determinada por área geográfica;
- pickup em loja para combinações de janela e retirada local.

### 5. Entrega e encerramento

Ao final da entrega:

- confirmação via app ou dispositivo;
- atualização de status para OMS/ERP;
- ajuste do inventário local ou externo;
- registro de devolução ou falha, se ocorrer.

## Arquitetura operacional

### Componentes da solução

- OMS / order orchestration
- WMS regional e WMS de loja
- Inventory management e inventory allocation engine
- TMS / routing engine
- Service layer para SHD e SDD
- API gateway e event bus
- Pátio / dock management
- Mobile workforce / courier app
- Camada de monitoramento e observabilidade

### Topologia de atuação

- Armazém externo: grande capacidade e maior cobertura de SKU.
- Hub urbano / loja regional: atendimento rápido e micro-fulfillment.
- Cliente final: localizado em área urbana densamente povoada.

A operação exige forte coordenação entre os três níveis, com regras operacionais claras para priorizar a origem mais adequada do estoque.

## Regras de estoque e disponibilidade

### Gestão de estoque local

Os estoques de loja precisam ser administrados para atender simultaneamente:

- operações da própria loja;
- pedidos de e-commerce local;
- pedidos de SHD;
- pedidos de SDD;
- reservas de atendimento imediato.

### Regras recomendadas

- reservar percentual específico do estoque para canal de entrega rápida;
- separar inventário por tipo de uso (loja, omnichannel, estoque de urgência);
- bloquear itens de alta demanda para entrega expressa apenas quando a venda local não estiver ameaçada;
- permitir reposição automática por transferências do armazém externo.

### Políticas de estoque mínimo

- estoque mínimo de serviço para regiões densas;
- estoque mínimo estratégico para itens de maior conversão;
- regras de replenishment por previsão por zona, horário e canal.

## Modelos de entrega

### Same Day Delivery (SDD)

O SDD é apropriado para:

- pedidos realizados até determinado horário do dia;
- regiões com alta aderência e densidade urbana;
- itens com tempo de montagem e embalagem reduzidos;
- entregas em áreas onde a corrida de distribuição não exige deslocamento extremo.

### Same Hour Delivery (SHD)

O SHD exige:

- origem do estoque muito próxima ao cliente;
- capacidade da loja ou hub urbano para cumprir a janela em tempo real;
- operação de couriers ou executores dedicados;
- processos de picking e embalagem acelerados;
- orientação geográfica e detecção de congestionamento.

## Requisitos de integração

### Sistemas envolvidos

- ERP de bens e cadastros
- OMS / order management
- WMS de armazém e WMS de loja
- TMS / routing engine
- CRM e loyalty
- API de e-commerce e canais digitais
- Sistema de mensageria / event bus
- Aplicativos de rastreio e mobile delivery

### Padrões de comunicação

- APIs síncronas para validação de estoque, reserva e confirmação.
- Mensageria assíncrona para eventos de pedido, entrega e inventário.
- CDC para sincronização de dados de SKU, loja, estoque e pedidos.
- Contratos de integração com schemas versionados.

## Requisitos não funcionais

### Disponibilidade

- operação em tempo real com tolerância baixa a indisponibilidade dos serviços de inventário e roteamento;
- redundância de pontos de processamento para hubs urbanos e armazéns centrais;
- failover para consumo de pedidos em zonas prioritárias.

### Performance

- SLA de confirmação de estoque em tempo real;
- processamento de alocação em poucos segundos;
- baixa latência para APIs de disponibilidade e reserva; 
- suporte a picos de demanda em promoções e horários de maior movimentação.

### Escalabilidade

- capacidade de agregar milhares de pedidos por hora em zonas metropolitanas;
- ajuste de infraestrutura para picos sazonais;
- modelagem horizontal de serviços, filas e workers de entrega.

### Segurança

- autenticação para APIs de terceiros e parceiros;
- proteção das informações de clientes e endereços;
- controle de acesso por perfil e região;
- rastreabilidade de pedidos e entregas.

## Operação e governança

### KPI em operação

- tempo de resposta de reserva;
- taxa de entrega em SHD; 
- taxa de SDD realizado no prazo;
- tempo de picking e embalagem;
- porcentagem de pedidos atendidos por loja local;
- tempo médio de reposição de loja;
- número de itens sem estoque em zona crítica;
- custo por pedido entregue.

### Governança operacional

- felxibilidade para priorizar regiões ou canais;
- indicadores de qualidade por loja/hub;
- medidas de eficiência e SLA por motorista, loja e região;
- regras de compensação e reprocessamento em falhas.

## Riscos e mitigação

### Risco 1: indisponibilidade local

**Impacto:** pedidos não atendidos em SHD/SDD.

**Mitigação:** reserva estratégica, reposição automática, fallback para armazém externo.

### Risco 2: inconsistência de estoque entre loja e centro

**Impacto:** oversell e cancelamentos.

**Mitigação:** reservas por zona, reconciliação contínua, integração em tempo real com WMS e OMS.

### Risco 3: alta demanda em período de pico

**Impacto:** congestionamento e falha na janela de entrega.

**Mitigação:** regras de dimensionamento, filas de prioridade e modelos de split por região.

### Risco 4: logística de última milha complexa

**Impacto:** atrasos e custo elevado.

**Mitigação:** roteamento inteligente, gestão por centroides urbanos e priorização por geolocalização.

## Recomendação arquitetural

A operação deve ser projetada como um sistema omnichannel de logística urbana com dois níveis principais de serviço:

1. um nível regional de estoques de grande porte fora da cidade;
2. um nível urbano de micro-estoques em lojas e hubs de proximité.

A combinação desses dois níveis torna a operação mais resiliente e mais rápida, desde que exista uma camada de orquestração capaz de:

- decidir a melhor origem por pedido;
- usar regras de alocação por SLA;
- gerir a reserva de estoque de forma segura;
- reduzir a latência entre o pedido e a entrega;
- controlar custo e nível de serviço com base em indicadores em tempo real.

A solução ideal combina WMS distribuído, order orchestration, event-driven integration e TMS de roteamento geográfico, conectados por uma camada de integração assíncrona e APIs síncronas para o momento crítico da venda.

## Próximos passos

1. Mapear os principais SKUs e regiões com alta densidade de demanda.
2. Definir os critérios de elegibilidade para SHD e SDD por zona urbana.
3. Definir a política de estoque local e a regra de reposição por loja/hub.
4. Validar o fluxo de reserva, picking e entrega em um piloto por região metropolitana.
5. Medir indicadores e ajustar a estratégia de alocação e capacidade.

## Conclusão

O serviço de Same Day Delivery e Same Hour Delivery em uma operação logística metropolitana exige uma arquitetura híbrida de estoque e atendimento. O grande armazém externo garante escala e custo eficiente, enquanto os estoques regionais em lojas físicas introduzem velocidade e proximidade ao cliente final. A combinação entre esses níveis, coordenada por uma camada de alocação, integração e gestão de operação, é a base para um serviço competitivo, escalável e resiliente.
