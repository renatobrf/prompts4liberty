# Arquitetura Técnica: Hackathon de Data Recognition com OpenCV e Tesseract OCR

## Resumo executivo

Este documento descreve uma solução técnica para ler um repositório de imagens contendo documentos digitalizados de clientes e operações, recuperar seu conteúdo textual e entregar os dados em um formato estruturado. A solução foi pensada para um hackathon interno cujo objetivo principal é obter o melhor score possível de leitura, mantendo uma implementação simples, reproduzível e suficientemente rastreável para comparar experimentos.

A proposta usa:

- **OpenCV** para inspeção, correção e melhoria das imagens;
- **Tesseract OCR** para reconhecimento do texto;
- um pipeline orientado a arquivos para processar um bucket grande de imagens;
- múltiplas estratégias de pré-processamento para lidar com baixa qualidade;
- pós-processamento e validação por campo;
- um conjunto de avaliação com gabarito, métricas e rastreabilidade de cada experimento.

O maior ganho esperado não vem apenas da troca do motor OCR. Para este cenário, a qualidade da imagem, a orientação, o contraste, o ruído, a resolução e o recorte do documento influenciam diretamente o resultado. Portanto, a arquitetura deve permitir testar várias versões da mesma imagem e escolher o resultado mais provável por documento ou por campo.

```text
Bucket de imagens
       |
       v
Inventário e amostragem
       |
       v
OpenCV: orientação, corte, escala, contraste, ruído, binarização
       |
       +--> variante A: imagem original normalizada
       +--> variante B: grayscale + threshold
       +--> variante C: adaptive threshold + denoise
       +--> variante D: correção de perspectiva + threshold
       |
       v
Tesseract OCR com configurações por layout
       |
       v
Pós-processamento, normalização e validação de campos
       |
       v
Escolha do melhor resultado + score + evidências
       |
       +--> JSON/CSV estruturado
       +--> texto OCR completo
       +--> métricas e imagens intermediárias
```

A solução deve otimizar o score do hackathon sem confundir score de OCR com qualidade de negócio. Um texto que possui muitos caracteres reconhecidos, mas erra o número da apólice, o CPF, o valor ou a data, pode ter um bom score geral e ainda ser inútil. Por isso, a avaliação deve combinar métricas de texto completo com acurácia dos campos de interesse.

---

## 1. Contexto e objetivo

### 1.1 Contexto

O repositório contém um grande volume de imagens com documentos internos relacionados a clientes e operações. As imagens podem ter sido produzidas por scanners, câmeras, sistemas legados ou conversões de documentos, apresentando diferenças de:

- resolução e compressão;
- orientação e rotação;
- iluminação e contraste;
- inclinação e perspectiva;
- ruído, manchas e artefatos;
- fontes, tamanhos e layouts;
- documentos com uma ou várias páginas;
- carimbos, assinaturas, tabelas e campos manuscritos;
- idioma, acentuação e símbolos financeiros.

O hackathon precisa entregar uma abordagem objetiva, capaz de transformar as imagens em dados comparáveis e medir rapidamente quais combinações de processamento geram o melhor resultado.

### 1.2 Objetivo principal

Maximizar a qualidade de recuperação dos dados dos documentos digitalizados usando OpenCV e Tesseract OCR, com baixo tempo de implementação e capacidade de executar em lote sobre o repositório de imagens.

### 1.3 Objetivos específicos

| ID | Objetivo |
|---|---|
| HDR01 | Inventariar e validar o repositório de imagens |
| HDR02 | Melhorar as imagens antes do OCR com OpenCV |
| HDR03 | Testar configurações de layout e idioma do Tesseract |
| HDR04 | Extrair texto completo e campos relevantes dos documentos |
| HDR05 | Comparar variantes e selecionar o melhor resultado |
| HDR06 | Medir o score com um conjunto de verdade de referência |
| HDR07 | Processar grandes volumes com reexecução e rastreabilidade |
| HDR08 | Documentar limitações, hipóteses e próximos ganhos |

### 1.4 Fora do escopo do hackathon

- Construir uma plataforma definitiva de gestão documental;
- garantir reconhecimento de escrita manuscrita com alta precisão;
- substituir validações legais ou humanas sobre documentos;
- inferir informações que não estão visíveis na imagem;
- transformar OCR em fonte oficial para decisão de seguro sem validação;
- resolver todos os tipos de documentos com um único modelo ou configuração.

---

## 2. Hipóteses para maximizar o score

O hackathon deve começar com hipóteses testáveis, em vez de processar todo o bucket com uma única configuração.

| Hipótese | Como testar | Indicador |
|---|---|---|
| A qualidade da imagem é o maior limitador | Comparar imagem original e variantes OpenCV | CER/WER e acurácia por campo |
| A escala da imagem influencia a leitura | Executar OCR em 1x, 1,5x, 2x e 3x | Score e tempo por página |
| O layout do documento exige PSM diferente | Comparar `--psm` por tipo de página | Acurácia de texto e campos |
| Documentos inclinados prejudicam o OCR | Aplicar deskew antes do Tesseract | Erros de linha e alinhamento |
| Uma única variante não serve para todo o bucket | Classificar imagens por qualidade e layout | Score por grupo |
| O melhor OCR pode variar por campo | Selecionar resultado por campo | Field accuracy |
| Pós-processamento corrige erros previsíveis | Normalizar datas, documentos e valores | Acurácia final estruturada |
| Resultados de múltiplas variantes podem ser combinados | Comparar candidatos por confiança e regras | Score final e taxa de revisão |

A equipe deve registrar quais hipóteses foram confirmadas ou rejeitadas. Isso evita que o score final dependa de alterações não reproduzíveis feitas manualmente durante a competição.

---

## 3. Critérios de sucesso

### 3.1 Sucesso técnico

- O pipeline processa o conjunto de imagens sem depender de intervenção manual por arquivo.
- Cada resultado pode ser relacionado ao arquivo de origem, à versão do código e aos parâmetros usados.
- Imagens com falha são separadas, não desaparecem silenciosamente.
- O processamento pode ser retomado sem repetir arquivos já concluídos.
- O score pode ser reproduzido a partir do mesmo conjunto de entrada.

### 3.2 Sucesso de reconhecimento

- O texto extraído supera uma linha de base definida pela organização.
- Os campos prioritários atingem a acurácia mínima acordada.
- A solução identifica documentos ilegíveis ou ambíguos para revisão.
- O pós-processamento reduz erros previsíveis sem criar valores inventados.
- A solução apresenta o melhor resultado por tipo de documento e não apenas uma média global.

### 3.3 Sucesso de hackathon

O resultado final deve permitir responder rapidamente:

1. Qual imagem foi processada?
2. Qual variante OpenCV foi usada?
3. Qual configuração do Tesseract produziu o texto?
4. Qual foi o score daquele resultado?
5. Quais campos foram reconhecidos com baixa confiança?
6. É possível reproduzir o resultado?
7. Qual ajuste aumenta o score sem elevar desproporcionalmente o tempo?

---

## 4. Arquitetura proposta

### 4.1 Visão lógica

```text
+-------------------+
| Repositório       |
| de imagens        |
+---------+---------+
          |
          v
+-------------------+
| Inventário        |
| hash, formato,    |
| dimensão, metadado|
+---------+---------+
          |
          v
+-------------------+
| Amostragem e      |
| classificação     |
| de qualidade      |
+---------+---------+
          |
          v
+-------------------+
| Pipeline OpenCV   |
| N variantes       |
+---------+---------+
          |
          v
+-------------------+
| Workers Tesseract |
| idioma e PSM      |
+---------+---------+
          |
          v
+-------------------+
| Parser e          |
| normalização      |
+---------+---------+
          |
          v
+-------------------+
| Scoring e seleção |
| do melhor output  |
+---------+---------+
          |
          v
+-------------------+
| JSON, CSV, texto, |
| métricas e evidênc.|
+-------------------+
```

### 4.2 Componentes

| Componente | Responsabilidade | Tecnologia sugerida |
|---|---|---|
| Inventário | Listar imagens, hashes, dimensões, formatos e status | Python, filesystem ou SDK do bucket |
| Loader | Ler imagens com tratamento de erro | OpenCV `imread` ou equivalente |
| Quality analyzer | Medir blur, brilho, contraste, resolução e orientação | OpenCV e heurísticas |
| Preprocessor | Gerar variantes normalizadas | OpenCV |
| OCR worker | Executar o Tesseract e capturar saída e confiança | Tesseract via CLI ou `pytesseract` |
| Extractor | Identificar campos por layout, regex e regras | Python, regex, parsers de domínio |
| Scorer | Comparar com gabarito e calcular métricas | Python |
| Result store | Persistir outputs e rastreabilidade | JSONL, SQLite, Parquet ou banco simples |
| Orchestrator | Distribuir, retomar e consolidar jobs | Script batch, multiprocessing ou fila |
| Review viewer | Inspecionar imagem, OCR e campos | HTML simples, notebook ou Grafana opcional |

Para o hackathon, a arquitetura deve começar simples. Uma fila distribuída só deve ser adicionada se o volume ou o tempo de execução impedir o uso de workers locais ou de um job batch paralelo.

---

## 5. Inventário e preparação do dataset

### 5.1 Inventário inicial

Antes de executar OCR em massa, criar um inventário com pelo menos:

```text
image_id
source_path
source_bucket
file_name
file_extension
file_size_bytes
sha256
width
height
channels
color_space
created_at, se disponível
document_group, se disponível
processing_status
```

O hash evita processar duas vezes o mesmo arquivo e ajuda a detectar alterações no repositório. A dimensão e a proporção da imagem são importantes para escolher escala, orientação e configuração de layout.

### 5.2 Formatos suportados

Verificar explicitamente:

- JPEG, PNG, TIFF e PDF convertido em imagem;
- imagens coloridas, grayscale e binárias;
- páginas únicas e sequências de páginas;
- imagens corrompidas, truncadas ou vazias;
- DPI real ou ausente;
- canal alpha e fundos transparentes.

A extensão do arquivo não deve ser considerada prova suficiente do formato. O loader deve validar o conteúdo e registrar a falha quando a imagem não puder ser aberta.

### 5.3 Conjunto de avaliação com gabarito

Separar o dataset em:

| Conjunto | Uso |
|---|---|
| Desenvolvimento | Criar e ajustar pipelines |
| Validação | Comparar variantes sem memorizar exemplos |
| Teste final | Medir o resultado final do hackathon |
| Casos difíceis | Baixa resolução, ruído, rotação, carimbo, tabela ou baixa iluminação |

O conjunto de teste final deve ficar protegido contra ajustes contínuos. Se a equipe usa o mesmo conjunto para decidir cada alteração, o score deixa de representar a capacidade de generalização.

### 5.4 Ground truth

Para cada imagem ou campo, o gabarito deve conter a resposta esperada e a política de comparação:

```json
{
  "image_id": "doc-000123",
  "document_type": "apolice",
  "text_reference": "texto normalizado do documento",
  "fields": {
    "numero_apolice": "123456789",
    "cpf_cliente": "12345678909",
    "data_inicio": "2026-01-01",
    "valor_premio": "1250.50"
  }
}
```

O gabarito precisa registrar diferenças aceitáveis, como acentuação, espaços, quebras de linha, pontuação e formatação de moeda. O valor comparado deve ser normalizado de forma consistente para não premiar ou punir apenas diferenças de apresentação.

---

## 6. Classificação inicial das imagens

A classificação não precisa usar GenAI ou um modelo complexo. Heurísticas simples ajudam a escolher o pipeline adequado.

### 6.1 Indicadores de qualidade

| Indicador | Interpretação |
|---|---|
| Largura e altura | Resolução disponível para reconhecer caracteres |
| DPI | Densidade de digitalização, quando confiável |
| Variância do Laplaciano | Estimativa de foco ou blur |
| Média de luminância | Imagem escura ou clara demais |
| Desvio padrão de luminância | Contraste disponível |
| Percentual de pixels extremos | Possível saturação ou binarização ruim |
| Proporção | Possível orientação ou classe de documento |
| Linhas detectadas | Tabelas, bordas, sublinhados e estrutura |
| Componentes conectados | Densidade aproximada de texto e ruído |
| Inclinação dominante | Necessidade de deskew |

Esses indicadores devem orientar a estratégia, não definir sozinhos se uma imagem é útil. Uma imagem com baixo contraste pode conter dados recuperáveis depois de uma transformação adequada.

### 6.2 Classes de qualidade sugeridas

```text
Q1 - boa resolução, foco e contraste
Q2 - resolução aceitável com ruído ou iluminação irregular
Q3 - inclinação, perspectiva ou fundo problemático
Q4 - baixa resolução, blur forte ou informação parcialmente ilegível
Q5 - ilegível ou corrompida; encaminhar para revisão
```

Cada classe pode receber um conjunto diferente de variantes OpenCV e configurações Tesseract. Isso reduz o custo de testar todas as combinações para todas as imagens.

---

## 7. Pipeline de pré-processamento com OpenCV

Não existe uma transformação universalmente melhor. O pipeline deve gerar variantes controladas e manter a imagem original intacta.

### 7.1 Pipeline base

```text
Imagem original
    -> leitura e validação
    -> orientação e rotação
    -> conversão para grayscale
    -> remoção de bordas e margens
    -> correção de inclinação
    -> escala adequada
    -> redução de ruído
    -> aumento de contraste
    -> binarização opcional
    -> morfologia opcional
    -> recorte de regiões
    -> imagem candidata para OCR
```

### 7.2 Conversão para grayscale

A conversão para escala de cinza reduz a complexidade da imagem e costuma ser adequada para documentos impressos. Deve-se preservar a imagem colorida quando a cor carregue informação relevante, como carimbos, marcações ou campos de validação.

Testar pelo menos:

- `cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)`;
- canal de luminância em imagens coloridas;
- canal com melhor contraste para documentos fotografados.

### 7.3 Redimensionamento

Caracteres pequenos podem exigir aumento antes do OCR. Testar fatores controlados, por exemplo:

```text
1.0x: referência de custo e qualidade
1.5x: aumento moderado
2.0x: candidato principal para texto pequeno
3.0x: casos de baixa resolução, com maior custo
```

O aumento não cria informação inexistente. Ele pode apenas tornar os contornos mais fáceis para o OCR. Deve ser acompanhado de uma métrica de custo e de uma regra para não ultrapassar dimensões que causem consumo excessivo de memória.

### 7.4 Redução de ruído

Testar conforme o tipo de defeito:

- `GaussianBlur` para ruído distribuído;
- `medianBlur` para ruído impulsivo;
- `bilateralFilter` quando for necessário preservar bordas;
- operações morfológicas para remover pequenos pontos;
- filtros leves para não apagar traços finos de caracteres.

O filtro deve ser comparado com a imagem sem filtro. Um processamento agressivo pode remover acentos, pontos, vírgulas ou partes de números.

### 7.5 Contraste e iluminação

Para imagens com iluminação irregular:

- equalização global quando o fundo for uniforme;
- CLAHE para melhorar contraste local;
- correção de background quando houver sombra ou gradiente;
- normalização de luminância antes da binarização.

O resultado deve ser avaliado visualmente em amostras e quantitativamente no score. Melhor aparência humana não garante melhor OCR.

### 7.6 Binarização

Testar variantes:

- threshold global;
- Otsu;
- adaptive threshold mean;
- adaptive threshold Gaussian;
- binarização invertida quando o texto estiver claro sobre fundo escuro.

A escolha depende da iluminação, do fundo e do tipo de documento. Guardar o parâmetro usado em cada resultado para permitir reprodução.

### 7.7 Deskew

Pequenas inclinações prejudicam a segmentação de linhas e colunas. Uma abordagem simples é:

1. detectar bordas ou pixels de texto;
2. estimar a linha dominante com Hough transform ou projeção;
3. calcular o ângulo;
4. rotacionar mantendo a imagem completa;
5. repetir o OCR para validar o ganho.

Limitar o ângulo de correção evita transformar uma imagem já correta em uma imagem pior. Rotação de 90, 180 e 270 graus deve ser tratada separadamente quando a orientação estiver incerta.

### 7.8 Correção de perspectiva

Para imagens fotografadas ou digitalizadas com bordas inclinadas:

- identificar o quadrilátero do documento;
- aplicar transformação de perspectiva;
- cortar margens externas;
- normalizar a proporção da página.

A detecção automática pode falhar em documentos sem borda clara. Quando falhar, manter a imagem original e registrar a falha; não descartar o documento.

### 7.9 Morfologia e linhas

Operações de abertura, fechamento, erosão e dilatação podem:

- remover pequenos ruídos;
- conectar partes quebradas de caracteres;
- remover linhas de tabela antes do OCR;
- destacar linhas horizontais e verticais;
- separar regiões de formulário.

Usar kernels pequenos e testar o impacto em números e letras finas. Remover linhas de tabela pode melhorar o texto, mas também remover sublinhados que indicam campos.

### 7.10 Cropping por região de interesse

Quando o tipo de documento for conhecido, dividir a página em regiões pode aumentar muito o score:

```text
Cabeçalho: tipo, número e data
Identificação: cliente e documento
Coberturas: tabela e valores
Rodapé: assinatura, observações e protocolo
```

Cada região pode usar `--psm` e pré-processamento próprios. O recorte deve guardar coordenadas na imagem original para permitir auditoria visual.

---

## 8. Estratégia de configuração do Tesseract

### 8.1 Idioma

Configurar corretamente os idiomas disponíveis, por exemplo:

```text
por
eng
por+eng
```

Usar mais idiomas pode aumentar o espaço de hipóteses e piorar o resultado quando o documento é predominantemente de um idioma. A escolha deve ser avaliada no conjunto de validação.

### 8.2 Page Segmentation Mode

O `--psm` deve refletir o layout da imagem:

| PSM | Uso típico |
|---:|---|
| 3 | Página com segmentação automática |
| 4 | Bloco de texto com possíveis colunas |
| 6 | Um bloco uniforme de texto |
| 7 | Uma única linha |
| 8 | Uma única palavra |
| 10 | Um único caractere |
| 11 | Texto esparso |
| 12 | Texto esparso com orientação |
| 13 | Linha crua, quando apropriado |

Os valores dependem da versão do Tesseract e do documento. A melhor prática para o hackathon é testar poucos PSMs representativos e selecionar por classe de documento ou qualidade, em vez de executar todos sem controle.

### 8.3 OEM e configuração

Testar o modo de engine disponível na versão instalada e registrar:

```text
versão do Tesseract
versão dos dados treinados
idioma
OEM
PSM
DPI informado
whitelist ou blacklist, quando utilizada
configurações de preservação de espaços
```

Para campos numéricos conhecidos, uma whitelist pode reduzir confusão entre letras e números, mas deve ser usada apenas na região correta. Uma whitelist aplicada ao documento inteiro pode remover informações legítimas.

### 8.4 Saídas do OCR

Gerar mais de uma saída para análise:

- texto simples;
- TSV com bounding boxes, confiança e níveis de bloco;
- HOCR ou ALTO quando a posição for necessária;
- imagem anotada para inspeção;
- confidência média e distribuição por palavra.

A confidência do Tesseract é um sinal útil, mas não deve ser usada como verdade absoluta. Um número incorreto pode receber confiança alta e um caractere correto em uma imagem ruim pode receber confiança baixa.

### 8.5 Exemplo de execução

```bash
tesseract input.png stdout \
  --oem 1 \
  --psm 6 \
  -l por+eng \
  tsv
```

A execução real deve capturar código de retorno, stderr, tempo, parâmetros, versão e caminho da imagem. O resultado deve ser escrito em arquivo temporário e movido para o destino somente após validação completa.

---

## 9. Ensemble de variantes

Para maximizar o score, processar uma imagem com uma única combinação pode ser inferior a executar um conjunto pequeno de candidatos.

### 9.1 Matriz de experimentos

Uma matriz inicial pode combinar:

| Dimensão | Candidatos |
|---|---|
| Escala | 1x, 1,5x, 2x |
| Imagem | original grayscale, CLAHE, threshold Otsu |
| Ruído | sem filtro, median, Gaussian |
| Orientação | original, deskew, rotações candidatas |
| Layout | PSM 3, 6, 11 |
| Idioma | `por`, `por+eng` |
| Região | página inteira, campos prioritários |

Não executar a matriz completa em todo o bucket sem medir custo. Começar com uma amostra estratificada e eliminar combinações que não produzem ganho.

### 9.2 Seleção do melhor resultado

A seleção pode usar uma função de score composta:

```text
score_total =
    w_text * score_texto
  + w_fields * score_campos
  + w_confidence * score_confianca
  - w_cost * penalidade_de_tempo
  - w_invalid * penalidade_de_valores_invalidos
```

Durante o hackathon, os pesos devem refletir a regra oficial de pontuação. Se o objetivo é recuperar campos de negócio, `score_campos` deve ter prioridade sobre a confiança média ou sobre a quantidade total de caracteres.

### 9.3 Seleção por campo

O melhor resultado para o número da apólice pode vir de uma variante diferente da melhor variante para o endereço. Quando o layout e as regiões são conhecidos, selecionar por campo pode gerar ganho maior que selecionar um texto único para a página inteira.

```text
Documento
  -> candidato A: melhor cabeçalho
  -> candidato B: melhor tabela
  -> candidato C: melhor rodapé
  -> consolidação e validação cruzada
```

É obrigatório manter o vínculo entre cada campo e a imagem, variante, bounding box e confiança que o produziram.

### 9.4 Quando não usar ensemble

Evitar ensemble amplo quando:

- o custo de execução excede o tempo disponível;
- não existe conjunto de validação para provar ganho;
- os resultados são altamente correlacionados;
- a seleção usa apenas confiança sem ground truth;
- a complexidade impede reproduzir o resultado final.

---

## 10. Extração e normalização dos dados

O OCR produz texto; a solução precisa produzir dados úteis.

### 10.1 Pipeline de pós-processamento

```text
Texto e bounding boxes
       |
       v
Normalização de espaços, acentos e quebras
       |
       v
Identificação do tipo de documento
       |
       v
Extração por região, rótulo e padrão
       |
       v
Normalização de data, moeda e identificadores
       |
       v
Validação semântica e checksums
       |
       v
JSON estruturado + evidência original
```

### 10.2 Tipos de campos

| Campo | Tratamento sugerido |
|---|---|
| CPF/CNPJ | Remover pontuação para validação; preservar formato exibido separadamente |
| Número de apólice | Regex, tamanho esperado e validação por domínio |
| Data | Normalizar formatos e rejeitar datas impossíveis |
| Valor monetário | Normalizar separadores sem perder precisão |
| Código de produto | Whitelist e dicionário de códigos válidos |
| Nome | Preservar acentos quando recuperados; não “corrigir” automaticamente sem evidência |
| Endereço | Manter como texto e dividir apenas com regras confiáveis |
| E-mail | Validação sintática e normalização de caixa |
| Status | Mapear variações para valores canônicos |

### 10.3 Correções controladas

Erros comuns de OCR podem ser corrigidos apenas quando o contexto permitir:

```text
O -> 0 em campo exclusivamente numérico
I -> 1 em campo com formato conhecido
S -> 5 quando o checksum e o contexto forem consistentes
```

Nunca aplicar substituições globais ao texto completo. A letra `O` pode ser válida em nomes e palavras, e o número `0` pode mudar o significado de um identificador.

### 10.4 Validações

A extração deve produzir estados, não somente valores:

```json
{
  "field": "numero_apolice",
  "value": "123456789",
  "status": "valid",
  "confidence": 0.91,
  "source": {
    "image_id": "doc-000123",
    "variant": "otsu-deskew-2x-psm7",
    "page": 1,
    "bbox": [120, 80, 380, 42]
  }
}
```

Estados possíveis:

- `valid`: valor extraído e validado;
- `uncertain`: valor provável, mas com baixa confiança ou conflito;
- `missing`: campo não localizado;
- `invalid`: valor localizado, mas inválido;
- `not_applicable`: campo não esperado para o documento.

---

## 11. Scoring e métricas

### 11.1 Métricas de texto

| Métrica | Uso |
|---|---|
| CER | Taxa de erro por caractere; boa para documentos textuais |
| WER | Taxa de erro por palavra; penaliza palavras incorretas |
| Exact match | Texto ou campo exatamente igual ao gabarito |
| Normalized edit distance | Comparação tolerante após normalização |
| Precision/recall | Útil para extração de entidades e campos |

As métricas precisam declarar se espaços, acentos, caixa, pontuação e quebras de linha são normalizados antes da comparação.

### 11.2 Métricas de campos

Para cada campo prioritário:

```text
field_accuracy = campos_validos_corretos / campos_presentes_no_gabarito
```

Também medir:

- taxa de campo encontrado;
- taxa de valor válido;
- taxa de valor incorreto;
- confiança média dos acertos e erros;
- erro por tipo de documento;
- erro por classe de qualidade;
- erro por variante de pré-processamento;
- taxa de revisão humana necessária.

### 11.3 Score composto

Uma proposta de score interno:

```text
score_documento =
    0.30 * score_texto_normalizado
  + 0.50 * score_campos_prioritarios
  + 0.10 * score_validacao
  + 0.10 * score_completude
```

Os pesos são ilustrativos. O hackathon deve adaptar a fórmula à regra oficial. O importante é publicar a fórmula antes da competição final e não alterar pesos depois de observar os resultados.

### 11.4 Relatórios de erro

Gerar tabelas como:

```text
document_type | image_quality | preprocessing | psm | CER | field_accuracy
apolice       | Q1             | otsu-deskew   | 6   | ... | ...
certificado   | Q3             | clahe-2x      | 11  | ... | ...
```

Isso mostra onde existe ganho real e evita otimizar uma média que esconde uma classe de documento crítica.

---

## 12. Processamento em lote e escala

### 12.1 Execução simples

Para o hackathon, começar com um executor que:

1. lê o inventário;
2. seleciona arquivos pendentes;
3. processa uma imagem por job;
4. grava resultado atômico;
5. atualiza status;
6. registra erro e continua o lote.

Um arquivo por job facilita reprocessamento e paralelização.

### 12.2 Paralelismo

OpenCV e Tesseract consomem CPU e memória. Controlar o número de workers para evitar:

- swapping;
- disputa de CPU;
- excesso de processos Tesseract;
- saturação de disco;
- resultados inconsistentes por falta de recursos.

Medir throughput em imagens por minuto, tempo p50/p95 por página e memória máxima por worker.

### 12.3 Idempotência

A chave do processamento pode ser:

```text
job_id = hash(image_sha256 + pipeline_version + experiment_id)
```

Se o resultado já existe para a mesma combinação, o worker pode ignorar o processamento. Uma mudança na imagem ou nos parâmetros deve criar um novo resultado, sem sobrescrever o anterior.

### 12.4 Falhas

Registrar estados:

```text
DISCOVERED
VALIDATED
PREPROCESSED
OCR_COMPLETED
PARSED
SCORED
SUCCEEDED
FAILED_RETRYABLE
FAILED_PERMANENT
REVIEW_REQUIRED
```

Separar erro de leitura, erro de processamento, timeout, imagem ilegível e falha de validação. A mensagem de erro deve conter contexto suficiente para corrigir o problema.

### 12.5 Arquivos intermediários

Guardar imagens intermediárias apenas para:

- amostras de validação;
- casos difíceis;
- resultados abaixo do threshold;
- auditoria do hackathon;
- comparação entre variantes.

Para o bucket completo, pode ser mais barato guardar parâmetros e hashes do que todas as imagens geradas. Aplicar uma política de limpeza posterior.

---

## 13. Armazenamento do resultado

### 13.1 Estrutura de resultado

```json
{
  "image_id": "doc-000123",
  "source_sha256": "...",
  "pipeline_version": "hackathon-v3",
  "document_type": "apolice",
  "selected_variant": "gray-otsu-deskew-2x-psm6",
  "ocr": {
    "engine": "tesseract",
    "version": "5.x",
    "language": "por+eng",
    "psm": 6,
    "confidence_mean": 86.4,
    "text_path": "results/doc-000123.txt"
  },
  "fields": {
    "numero_apolice": {
      "value": "123456789",
      "status": "valid",
      "confidence": 0.94
    }
  },
  "score": {
    "cer": 0.08,
    "field_accuracy": 1.0,
    "total": 0.91
  },
  "review_required": false,
  "created_at": "2026-09-16T12:00:00Z"
}
```

### 13.2 Repositórios

| Artefato | Armazenamento recomendado |
|---|---|
| Inventário | CSV, Parquet, SQLite ou banco relacional simples |
| Texto OCR | JSONL, arquivos `.txt` ou object storage |
| Campos estruturados | JSONL, Parquet, PostgreSQL ou ClickHouse |
| Bounding boxes | TSV, JSON ou Parquet |
| Métricas | CSV/Parquet e dashboard simples |
| Imagens intermediárias | Diretório temporário ou object storage com TTL |
| Logs do pipeline | JSON estruturado |

Durante o hackathon, JSONL e Parquet oferecem simplicidade e bom suporte para análises. Um banco relacional pode ser útil para revisão, mas não deve atrasar a avaliação do OCR.

---

## 14. Segurança e proteção de dados

Os documentos podem conter dados pessoais, informações de clientes e dados operacionais. Mesmo em um hackathon, o pipeline deve respeitar controles mínimos.

- Restringir o acesso ao bucket e aos resultados.
- Não copiar imagens para notebooks ou máquinas pessoais sem autorização.
- Criptografar armazenamento e transporte quando aplicável.
- Não colocar dados reais em mensagens de erro, nomes de arquivo ou logs públicos.
- Mascarar CPF, documentos, tokens e dados sensíveis em dashboards de demonstração.
- Definir quem pode visualizar imagens originais e quem pode visualizar apenas campos extraídos.
- Preservar o hash e o identificador da imagem sem expor o conteúdo.
- Aplicar retenção e limpeza para artefatos intermediários.
- Manter os dados extraídos com o mesmo nível de proteção dos documentos fonte.
- Considerar as regras aplicáveis da operação de seguros e os controles relacionados à SUSEP.

O OCR não deve ser considerado mecanismo de anonimização. Texto extraído, bounding boxes e imagens processadas podem continuar contendo dados pessoais.

---

## 15. Plano de execução do hackathon

### Etapa 1: baseline

- Selecionar amostra representativa.
- Executar imagem original com uma configuração básica do Tesseract.
- Medir tempo, CER, WER, field accuracy e falhas.
- Registrar os principais erros visuais e textuais.

### Etapa 2: qualidade de imagem

- Implementar grayscale, escala, denoise, contraste, threshold e deskew.
- Comparar variantes isoladamente.
- Remover transformações que não gerem ganho comprovado.
- Separar resultados por classe de qualidade.

### Etapa 3: configuração do OCR

- Testar idiomas disponíveis.
- Comparar PSMs por layout.
- Testar whitelist apenas em campos adequados.
- Capturar TSV e confiança por palavra.

### Etapa 4: extração de campos

- Definir os campos prioritários.
- Implementar regiões, rótulos, regex e validadores.
- Corrigir erros somente com regras específicas de campo.
- Produzir JSON com fonte e evidência.

### Etapa 5: ensemble e seleção

- Executar combinações promissoras.
- Selecionar melhor candidato por documento ou campo.
- Avaliar custo adicional do ensemble.
- Congelar a versão vencedora e executar no teste final.

### Etapa 6: apresentação

Apresentar:

- baseline versus resultado final;
- score geral e score por campo;
- exemplos antes e depois;
- classes de documentos mais difíceis;
- tempo total e throughput;
- limitações conhecidas;
- arquitetura e estratégia de reprodução;
- próximos ganhos fora do escopo do hackathon.

---

## 16. Riscos e mitigações

| Risco | Impacto | Mitigação |
|---|---|---|
| Imagem com baixa resolução | Caracteres não recuperáveis | Escala, variantes, classificação e revisão |
| Threshold remove informação | Números e acentos incorretos | Comparar com imagem original e limitar transformações |
| PSM inadequado | Ordem e segmentação ruins | Configuração por layout e região |
| Confiança alta em valor errado | Seleção de candidato incorreta | Ground truth, validadores e score por campo |
| Regex de pós-processamento muito ampla | Valores inventados ou truncados | Regras específicas, checksum e status `uncertain` |
| Dataset desbalanceado | Score médio esconde documentos difíceis | Amostragem estratificada e métricas por classe |
| Overfitting no teste | Resultado não generaliza | Separar desenvolvimento, validação e teste final |
| Paralelismo excessivo | Instabilidade e baixo throughput | Limitar workers e medir recursos |
| Falha silenciosa | Imagens desaparecem do resultado | Inventário, estados, hashes e auditoria |
| Dados reais expostos | Incidente de privacidade | Controle de acesso, mascaramento e retenção |
| Processar tudo com ensemble | Tempo e custo excessivos | Seleção por qualidade e eliminação de variantes fracas |
| Documento manuscrito | Baixa capacidade do Tesseract | Identificar limitação e encaminhar para revisão ou outro modelo |

---

## 17. Recomendação final

Para o hackathon, recomenda-se implementar uma solução batch em Python com OpenCV e Tesseract, organizada em workers idempotentes e orientada por experimentos. A primeira versão deve priorizar:

1. inventário completo e hash das imagens;
2. conjunto de validação com ground truth;
3. baseline reproduzível;
4. cinco a oito variantes de pré-processamento relevantes;
5. PSM e idioma ajustados ao layout;
6. extração de campos prioritários;
7. validação por formato, checksum e domínio;
8. score por documento, campo e classe de qualidade;
9. armazenamento das evidências e parâmetros;
10. execução paralela controlada e retomável.

A estratégia vencedora provavelmente será uma combinação de melhoria da imagem, escolha de layout e validação de campos, e não apenas uma configuração isolada do Tesseract. O pipeline deve preservar a imagem original, registrar todas as transformações e permitir reproduzir o resultado final a partir do identificador da imagem e da versão do experimento.

O resultado do hackathon deve ser avaliado em duas dimensões: **qualidade de reconhecimento** e **qualidade da solução**. A melhor solução é aquela que obtém um score alto, processa o volume dentro do tempo disponível, explica seus resultados e pode evoluir para uma aplicação de produção sem depender de ajustes manuais escondidos.
