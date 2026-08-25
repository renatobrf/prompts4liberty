# contexto
- Industria de meios de pagamento oferecendo um gateway de processamento de operacoes financeiras em cartoes de credito, debito, boleto registrado e pix para integracao com o mercado financeiro brasileiro, em cumprimento com as normas do bacen e estabelecendo um canal seguro de comunicacao interbancaria (van).

# api e dashboard
- Conectividade com os parceiros por meio de troca de arquivos ou chamadas api.
- Dashboard de visibilidade operacional.

# arquitetura
- hiker validacao arquivos, carga de arquivos
- configServerFiles
- bulk files
- api gateway na aws cloud, que permite direcionar o fluxo de chamadas para a cloud ou para o ambiente on-premisse

# componente: hiker

## definição
O **Hiker** é um componente de travessia com contexto acumulado responsável por percorrer o ciclo de vida de um arquivo financeiro recebido pelo gateway — desde a chegada até a confirmação de carga — validando cada etapa e acumulando estado de auditoria ao longo do caminho, sem modificar a estrutura dos dados originais.

## responsabilidades
- **Recepção**: identificar e classificar o arquivo recebido (remessa, retorno, extrato, posição) conforme o layout esperado pelo parceiro (ex: CNAB 240, CNAB 400, XML BACEN, JSON PIX).
- **Validação estrutural**: percorrer os registros do arquivo verificando integridade de campos obrigatórios, tamanhos, tipos e regras de negócio por segmento.
- **Validação financeira**: verificar consistência de valores, datas de vencimento, dados do pagador/beneficiário e conformidade com normas do BACEN.
- **Acumulação de contexto**: manter estado da jornada de validação (erros, avisos, registros processados, totalizadores) entre cada passo da travessia.
- **Carga controlada**: ao final da travessia sem erros críticos, autorizar e registrar a carga dos dados no pipeline de processamento (bulk files).
- **Emissão de eventos**: publicar eventos de auditoria a cada etapa para o dashboard de visibilidade operacional.

## fluxo de travessia

```
[Arquivo Recebido (VAN / API)]
        │
        ▼
[Hiker: passo 1 — identificação e classificação]
        │  contexto: { tipo, parceiro, layout, timestamp }
        ▼
[Hiker: passo 2 — validação estrutural (header/trailer/segmentos)]
        │  contexto: + { registros_lidos, erros_estruturais[] }
        ▼
[Hiker: passo 3 — validação financeira e compliance BACEN]
        │  contexto: + { erros_financeiros[], avisos[], totalizadores }
        ▼
[Hiker: passo 4 — decisão de carga]
        │  contexto: + { status: "aprovado" | "rejeitado" | "pendente" }
        ▼
[configServerFiles → bulk files → pipeline de processamento]
        │
        ▼
[Evento de auditoria → Dashboard operacional]
```

## contrato de interface

```typescript
interface HikerContext {
  arquivoId: string;
  parceiro: string;
  layout: "CNAB240" | "CNAB400" | "XML_BACEN" | "JSON_PIX";
  timestamp: Date;
  registrosLidos: number;
  erros: HikerError[];
  avisos: string[];
  totalizadores: {
    quantidadeRegistros: number;
    valorTotal: number;
  };
  status: "em_travessia" | "aprovado" | "rejeitado" | "pendente_revisao";
}

interface HikerError {
  linha: number;
  campo: string;
  mensagem: string;
  critico: boolean;
}

interface Hiker {
  iniciar(arquivo: ArquivoFinanceiro): HikerContext;
  passo(segmento: Segmento, contexto: HikerContext): HikerContext;
  finalizar(contexto: HikerContext): ResultadoCarga;
}
```

## integrações
| Componente | Direção | Descrição |
|---|---|---|
| `configServerFiles` | ← | fornece as regras de layout e validação por parceiro |
| `bulk files` | → | recebe os registros aprovados para processamento em lote |
| `VAN / API` | ← | origem dos arquivos financeiros recebidos |
| `Dashboard` | → | consome os eventos de auditoria emitidos pelo Hiker |
| `BACEN / normas` | ← | referência de compliance aplicada nas validações financeiras |