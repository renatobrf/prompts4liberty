# PoC: CDN e cache de borda para site de varejo (picos sazonais)

Contexto
- Site de varejo com alto volume e picos sazonais. Front-end é estático (listas de produtos), mas precisa confirmar estoque e preço com origem ao interagir (página produto, checkout).
- Existe um processo periódico que atualiza o inventário, disponibilidade e preços.
- Objetivo: projetar uma solução de CDN / cache de borda para reduzir latência e carga de origem, mantendo consistência aceitável de preço/estoque.

Visão geral da solução (resumo)
- Usar CDN com cache de borda (CloudFront / Fastly / Cloudflare) e origin shield para reduzir carga na origem.
- Cachear páginas estáticas e recursos (`/products`, imagens, CSS, JS) com TTLs longos e estratégia de invalidação por versão (cache-busting) ou purge por tag.
- Para conteúdo sensível a preço/estoque, adotar TTL curto + stale-while-revalidate / stale-if-error e validação por purge/Tags quando houver atualização crítica.
- Utilizar chave de cache (cache key) que leve em conta país/currency, AB tests e headers relevantes (Accept-Language, device) — evitar incluir cookies de sessão na key.
- Implementar mecanismos de atualização em background (warm-up / prefetch) e fila de atualização quando inventário muda em massa.

Cache keys e Vary
- Chave recomendada: URL canônica (sem querystrings mutáveis) + cabeçalhos permitidos (Accept-Language, CloudFront-Viewer-Country) + fragmentos relevantes (currency param ou header).
- Ignore cookies de sessão para páginas públicas. Use cookies apenas para conteúdo personalizado (minimizar). Para conteúdo dependente de usuário use SSR ou edge compute com caching por user-hash se necessário.

Estratégias por tipo de recurso
- Assets estáticos (imagens, CSS, JS): Cache-Control: public, max-age=31536000, immutable. Usar fingerprinting no filename.
- Listagens de produtos (páginas HTML geradas static): Cache-Control: public, s-maxage=300, stale-while-revalidate=60. TTL 5 min (ajustável) com revalidação em background.
- Página de produto detalhado: s-maxage=60–300 dependendo da volatilidade; se preço muda frequentemente, usar 60s.
- Endpoints sensíveis (API de preço/estoque, checkout): não cachear no browser; usar cache de borda com s-maxage baixo (30–60s) ou não cachear; usar caching condicionado por headers ou tokens.

Headers recomendados (exemplos)
- Para recursos estáticos:
  Cache-Control: public, max-age=31536000, immutable

- Para páginas listagem:
  Cache-Control: public, s-maxage=300, stale-while-revalidate=60, stale-if-error=86400

- Para páginas produto (ex.: preço/estoque sensível):
  Cache-Control: public, s-maxage=60, stale-while-revalidate=30, stale-if-error=60

- Para respostas de API críticas (checkout):
  Cache-Control: private, no-store

CDN features a usar
- Origin Shield (CloudFront) / Shielding (ou origin shield) para reduzir conexões concorrentes à origem durante picos.
- Cache tagging (Fastly) ou surrogate keys para purge seletivo (quando produto X muda você apaga só keys relacionadas).
- Purge/Invalidate API para atualizações ponto-a-ponto (por produto sku).
- Tiered caching (CloudFront) / Tiered-caching ou origin failover para distribuir tráfego entre POPs.
- Workers/Edge Functions: para manipular cache key, reescrever headers ou retornar fallback em caso de erro.

Invalidação e atualização do cache
- Preferir purge por tag/surrogate-key: quando inventário ou preço mudar, sua pipeline de atualização envia a tag para a CDN para invalidar (ideal).
- Se o provider não suportar tags, usar cache-busting via versão na URL (ex: /products?v=20260904T1500) quando atualizar em massa.
- Estratégia híbrida: pequenas atualizações -> purge seletivo; lançamentos em massa -> alterar versão global (cache-bust) e enviar purge amplo controlado.

Consistência de preço/estoque
- Para garantir que o cliente veja preço/estoque consistente no checkout:
  1) Mostrar preço/estoque cacheado na listagem/produto com TTL curto e indicação de atualização ("preço verificado no checkout").
  2) Na ação de adicionar ao carrinho e antes do pagamento, revalidar com a API de origem (não cacheada ou com very short TTL) para última confirmação.
  3) Aplicar reserva temporária (hold) no estoque no backend durante fluxo de checkout (se aplicável) para evitar vendas por duplicidade.

Aquecimento de cache (cache warm-up)
- Em grandes eventos sazonais, usar:
  - Pre-warming: disparar requisições programáticas para os principais SKUs/pages para popular POPs regionais pouco antes do pico.
  - Canary e rollouts: começar com subset de POPs/regiões e aumentar.

Monitoramento e alertas
- Métricas: cache hit ratio, origin request rate, latency (p95/p99), bandwidth, error rate 5xx no origin.
- Alertas: subida de origin-requests > threshold, aumento de miss rate, erro 5xx.
- Logs: habilitar logs de acesso da CDN para análise (ex: CloudFront access logs, Fastly logs) + ingestão para ELK/Datadog.

Teste e validação
- Testes de carga simulando picos sazonais (abtest com tráfego real se possível).
- Teste de invalidation: alterar um SKU e verificar se purge/tag remove item do cache em tempo esperado.
- Monitorar latência e origin-load durante testes.

Exemplo de workflow de atualização de preço/estoque
1. Atualização no sistema ERP -> envia evento para fila (Kafka/SQS).
2. Worker processa evento e atualiza base de dados + envia purge por surrogate-key para CDN (ou marca versão).
3. Worker dispara pré-busca (warm-up) para emissões de cache críticas se necessário.
4. Sistema de monitoramento confirma que os hits no origin caíram e que a nova informação está servida.

Tecnologias e fornecedores (opções)
- CloudFront (AWS): bom para integração com origin AWS, origin shield, Lambda@Edge. Invalidações por path (mais caras) — usar versionamento e/ou Lambda@Edge para headers.
- Fastly: excelente controle, suporte a surrogate-keys (cache tags), VCL customizável, purges por tag rápidas.
- Cloudflare: fácil de usar, Workers para lógica de borda, cache-tiering, API de purge por URL e cache tags em Workers.

Checklist de implementação rápida (MVP)
- [ ] Definir cache key e quais headers incluir/excluir
- [ ] Configurar CDN com origin shield e regras de TTL por path
- [ ] Implementar surrogate-keys / tags nas respostas de origem (se suportado)
- [ ] Implementar pipeline que envia purge por tag quando inventário/preço mudar
- [ ] Configurar stale-while-revalidate para listagens
- [ ] Preparar playbook de pre-warm antes dos picos
- [ ] Instrumentar métricas e dashboards (hit ratio, origin RPS, p95 latency)

Conclusão
- A combinação de TTLs curtos para conteúdo volátil, stale-while-revalidate para experiência fluida, purge/tag para invalidações precisas, e cache-busting para mudanças em massa provê o equilíbrio entre desempenho e consistência.
- Escolha do CDN deve considerar suporte a surrogate-keys (muito útil), APIs de purge, e integração com sua infra atual. Em eventos sazonais, origin shield + pre-warm + monitoramento ativo são essenciais.

Referências rápidas (para configuração)
- Cache-Control (RFC 7234): usar s-maxage para caches compartilhados
- Fastly surrogate-keys: usar para invalidar por produto
- CloudFront origin shield e Lambda@Edge: para manipular headers e lógica na borda

---

Notas: este documento foi gerado a partir do prompt original e contém recomendações práticas e configurações sugeridas que devem ser adaptadas ao provedor e arquitetura específicos.
