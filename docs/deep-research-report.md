# Оптимизация затрат при использовании OpenClaw без заметной потери качества и надежности

## Executive Summary

OpenClaw — «local-first» агентный gateway, который собирает **системный промпт + историю сессии + результаты tool calls + workspace bootstrap-файлы** и отправляет это провайдеру модели на каждый агентный прогон. Поэтому у OpenClaw почти всегда доминирует **стоимость контекста (input tokens)**, а затем — **стоимость повторов/ошибок** (retries, timeouts, failover) и **стоимость внешних инструментов** (web_search, web_fetch через Firecrawl, embeddings для памяти, медиа-предобработка). citeturn18search1turn14view0turn9view0

Самые сильные рычаги экономии в OpenClaw, если цель — «минус cost без заметной потери качества/надежности»:

1) **Максимизировать provider-side prompt caching** и минимизировать cache-write «перезапись» после TTL:  
— у entity["company","OpenAI","ai company"] cached input для GPT‑5.2 стоит **в 10 раз дешевле** ($0.175 против $1.750 за 1M input tokens), что делает повторяющиеся префиксы (системный промпт + bootstrap + стационарные инструкции) ключевым активом. citeturn11view0  
— OpenAI заявляет, что Prompt Caching может дать **до 90%** снижения стоимости input и **до 80%** улучшения latency (TTFT) и при этом «работает автоматически» на API-запросах. citeturn1search14turn1search6  
— OpenClaw отдельно подчеркивает экономику cache TTL: если сессия простаивает дольше TTL, следующий запрос может «перекэшировать» большой префикс; для этого есть **cache‑ttl pruning**, а также стратегия «подогрева» heartbeat’ом чуть меньше TTL. citeturn6search2turn6search0  
— у entity["company","Anthropic","ai company"] prompt caching read обычно ~в 10 раз дешевле base input (например, Sonnet 4.6: read $0.30/MTok при input $3/MTok), но write дороже (например, $3.75/MTok для ≤200k). Это делает «переписывание» кэша после TTL заметной статьей расходов, если вы часто «просыпаетесь» после пауз. citeturn1search3turn13view0

2) **Контекст-гигиена OpenClaw**: быстро режет input tokens почти без влияния на качество, если делать аккуратно:  
— держать bootstrap-файлы (AGENTS.md/SOUL.md/TOOLS.md/USER.md/HEARTBEAT.md и т.д.) компактными; OpenClaw явно предупреждает, что они инжектятся каждый раз и «едят токены», особенно MEMORY.md. citeturn14view0turn18search1  
— использовать `/context detail` и `/status`/`/usage tokens` для поиска «token hotspots»: tool schemas (JSON) **тоже** считаются в контекст, хотя пользователю их «не видно». citeturn18search1turn5search1  
— включить **session pruning** для больших toolResult, чтобы не таскать мегабайты stdout/HTML/JSON из прошлых инструментов. OpenClaw поддерживает soft-trim/hard-clear для `toolResult` и режим `cache-ttl` под Anthropic TTL. citeturn5search3turn6search0  
— ограничить group history injection (historyLimit) и не тащить «пачки» групповых сообщений в prompt. citeturn4search2turn4search0

3) **Task-based model assignment + дешево‑сначала/дорого‑в‑конце**:  
OpenClaw уже поддерживает явные модели/фолбэки, failover и overrides:  
— порядок выбора: primary → fallbacks; внутри провайдера есть profile‑rotation и cooldowns. citeturn3search3turn3search0  
— для cron (особенно isolated jobs) можно задавать **model/thinking overrides** и тем самым отправлять «дешевые» рутины на дешевую модель, а тяжелые отчеты — на сильную, не загрязняя main session. citeturn8search2turn8search5  
— subagents можно запускать с `--model`/`--thinking` overrides. При этом subagent сессии получают более «минимальный» promptMode, что делает их естественным контейнером для дешевой декомпозиции задач. citeturn3search13turn14view0

4) **Сдерживать «скачок цены» на long-context**: у ряда провайдеров стоимость резко растет после определенного порога prompt tokens.  
— на claude.com/pricing видно, что для Sonnet 4.6 input удваивается при >200K tokens ($3→$6/MTok), output тоже дорожает ($15→$22.5/MTok). citeturn13view0  
— у Gemini 2.5 Pro на официальной pricing-странице тоже есть двуставочная модель по порогу 200K и отдельная экономика context caching + storage. citeturn2search1turn2search5  
Вывод: для OpenClaw выгодно и безопасно **держать effective context ниже порога** с помощью pruning/compaction + RAG/памяти.

5) **Убрать «скрытые» платные вызовы** в OpenClaw: web_fetch через Firecrawl, web_search, embeddings, медиа‑процессинг, probes/scans/status snapshots. OpenClaw прямо перечисляет, какие функции могут тратить keys и где это видно. citeturn9view0turn8search1

### Топ-10 способов снизить cost (от наиболее универсальных к более продвинутым)

1. Максимизировать provider prompt caching hit rate (стабильный префикс + TTL‑стратегия) и минимизировать cache-write. citeturn1search14turn11view0turn6search0  
2. Включить и настроить `agents.defaults.contextPruning` и/или `cache-ttl` pruning для Anthropic‑профилей. citeturn5search3turn6search0  
3. Урезать tool surface: `tools.profile` + `tools.allow/deny` (уменьшает tool schemas в prompt и снижает риск runaway tool use). citeturn18search1turn8search0  
4. Сжать bootstrap-файлы и лимиты `bootstrapMaxChars/bootstrapTotalMaxChars`, убрать «монолитные» инструкции в TOOLS.md/AGENTS.md; переносить детализацию в skills и читать по требованию. citeturn14view0turn18search1  
5. Снизить `messages.groupChat.historyLimit`/per-channel historyLimit; отключать историю в шумных группах. citeturn4search2turn4search0turn19view1  
6. Жестко ограничить output через `maxTokens` (в OpenClaw это provider-specific param на уровне модели) и через «brevity» правила в systemPrompt/каналах. citeturn18search6turn19view1turn18search16  
7. Развести задачи по моделям: дешевые рутины (heartbeat/cron summaries/классификация/форматирование) → дешевые модели; «hard reasoning» → сильные; реализовать escalation. Опирается на исследования по routing/cascades. citeturn8search2turn7search1turn7search0  
8. Оптимизировать heartbeat/cron: батчить проверки, уменьшать частоту, ограничивать active hours, не слать reasoning, и использовать cron isolated jobs для «точных» задач. citeturn18search17turn8search5turn3search5  
9. Перевести memory embeddings на local/cheap, включить embedding cache и контролировать chunking (иначе embeddings могут стать неожиданной статьей расходов/ошибок). citeturn2search0turn6search1turn9view0turn18search18  
10. Построить внешний semantic cache/результат‑кэш (для повторяющихся запросов/брон/FAQ), с защитой от ошибок (verified/guarded caching, например идеи vCache). citeturn7search15turn7search23turn7search35  

### Самые быстрые wins

**За 1 день** (безархитектурно):  
— включить `/usage tokens` и регулярный `/status` или CLI `openclaw status --usage` для видимости; OpenClaw поддерживает и per-response footer, и локальную cost-агрегацию. citeturn5search1turn21view0  
— включить/настроить `contextPruning` и снизить group history limits. citeturn5search3turn4search2  
— урезать tool profile до «минимально нужного» и отключить тяжелые инструменты по умолчанию (browser/canvas/web_fetch и т.д.). citeturn8search0turn18search1  
— поставить `maxTokens` на модели и «Short answers» правила на каналы, где важна краткость. citeturn18search6turn19view1turn18search16  

**За 1 неделю** (умеренная инженерка):  
— внедрить модельный роутинг (cron isolated + subagents) и «cheap-first» escalation; зафиксировать fallback order по цене/надежности. citeturn8search2turn3search0turn7search1  
— включить cache‑ttl pruning (если Anthropic) и настроить heartbeat cadence под TTL. citeturn6search0turn6search2turn18search17  
— рефактор bootstrap (AGENTS/SOUL/TOOLS/MEMORY) в короткие «правила» + on-demand навыки. citeturn14view0turn18search1  

### Самые большие рычаги экономии

*Самая безопасная экономия:* **контекст‑гигиена** (pruning/compaction/history/tool surface/output caps) + провайдерный prompt caching. citeturn5search3turn18search1turn1search14turn11view0  
*Самая быстрая экономия:* ограничение tool surface + history limits + maxTokens. citeturn8search0turn4search2turn18search6  
*Самая большая экономия:* **multi-model routing + local/hybrid** (если ваш профиль задач допускает), особенно когда «агентная рутина» доминирует по числу вызовов. citeturn3search13turn8search2turn6search1turn7search0  
*Самая недооцененная оптимизация:* управление **cache-write после TTL** (cache‑ttl pruning + cadence), потому что write у Anthropic дороже base input и может «съедать» выгоду от read‑кэша при нерегулярных обращениях. citeturn1search3turn6search0turn6search2  

## Cost Map OpenClaw

### Разбивка источников затрат

**LLM inference (основное):** каждый agentic loop формирует context (system prompt + история + tool schemas + tool results + bootstrap files) и делает запрос к провайдеру модели. citeturn3search16turn18search1turn9view0  

**Provider caching и cacheRead/cacheWrite:** OpenClaw умеет показывать cacheRead/cacheWrite в `/status` и считает стоимость через `models.providers.*.models[].cost` (input/output/cacheRead/cacheWrite). При правильной настройке это превращается в «первоклассный» FinOps‑рычаг: вы видите hit‑rate и цену write/read. citeturn5search1turn6search3turn6search2  

**Embeddings и память:** memory_search по умолчанию может использовать удаленные embeddings (OpenAI/Gemini/Voyage/Mistral) или local; есть embedding cache в SQLite, чтобы не пере-эмбеддить одни и те же чанки. citeturn6search1turn9view0turn2search0  

**Web search / web fetch:** OpenClaw перечисляет web_search (Brave/Perplexity через OpenRouter) и web_fetch (Firecrawl, если задан ключ; иначе локальный direct fetch + readability). citeturn9view0turn15search3turn15search13  

**Media understanding:** входящие изображения/аудио/видео могут быть предварительно описаны/распознаны через провайдера, что добавляет токены и latency. citeturn9view0turn18search12  

**Health/usage probes, model scan/probe:** `models status --probe` и `models scan` могут делать реальные запросы и тратить токены/лимиты; OpenClaw явно предупреждает об этом. citeturn18search0turn9view0turn18search22  

### Типовые “token burn” сценарии

1) **Большой системный промпт** из-за широкой tool surface: tool schemas (JSON) добавляются в context и могут быть огромными. citeturn18search1turn8search0  
2) **Разросшиеся bootstrap файлы** (особенно MEMORY.md/TOOLS.md) — они инжектятся каждый раз; OpenClaw прямо просит держать их короткими и дает лимиты на инжект. citeturn14view0turn18search1  
3) **Групповые чаты**: накопление group history injection (по умолчанию лимиты типа 50), плюс mention-gating может буферизовать множество сообщений, которые потом заходят в prompt. citeturn4search2turn4search0turn4search15  
4) **Tool outputs**: длинные stdout/HTML/JSON/логи остаются в истории и повторно отправляются; без pruning стоимость растет «с каждой итерацией». citeturn5search3turn3search16  
5) **Heartbeat слишком частый или слишком «болтливый»**: это регулярные LLM вызовы, и каждый подогревает весь контекст; при `includeReasoning: true` вы платите еще и за «Reasoning: …» доставку. citeturn18search17turn3search5  

### Таблица “источник затрат → причина → симптомы → как детектить”

| Источник затрат | Наиболее частая причина | Симптомы | Как детектить (в OpenClaw и вокруг) |
|---|---|---|---|
| LLM input tokens | Большой system prompt (tools + bootstrap + skills metadata) | Высокие input токены даже на «простых» вопросах | `/context detail` + сравнение размера tool schemas и bootstrap; `/usage tokens` per reply citeturn18search1turn5search1 |
| LLM output tokens | Нет caps на output, модель «болтливая» | Рост output, latency, частые chunking-сообщения | Настроить `maxTokens` в model params; измерять output per run citeturn18search6turn18search16 |
| CacheWrite (особенно Anthropic) | Сессия простаивает > TTL → перекэширование большого префикса | Скачок `cacheWrite`, «первый запрос после паузы» резко дороже | `/status` cache stats; включить cache‑ttl pruning и/или heartbeat cadence citeturn6search0turn6search2turn6search3 |
| Web search API | Слишком частый web_search «на всякий случай» | Рост расходов на поиск, 429 → ретраи | Логировать tool calls; ограничить tool allowlist; задавать «search only if needed» правила citeturn9view0turn8search0 |
| Firecrawl | Частое попадание на JS-heavy сайты или неверная стратегия web_fetch | Платные web_fetch вызовы | Убедиться, что без ключа используется direct fetch + readability; мониторить долю Firecrawl fallback citeturn9view0turn15search13 |
| Embeddings | Remote embeddings по умолчанию + частые reindex | Регулярные небольшие, но постоянные траты; иногда ошибки лимитов чанка | Включить embedding cache; при необходимости перейти на local embeddings citeturn2search0turn6search1turn18search18 |
| Retries/timeouts | Слабая сеть/лимиты провайдера/слишком агрессивные таймауты | Дублированные LLM/tool вызовы, рост latency | Использовать встроенную retry policy; смотреть 429/timeout rate citeturn3search4turn3search0 |
| Probes/scans | Частое `--probe`, `models scan` | Неожиданные токены, rate-limit | Избегать probe в production; выделить отдельный «health window» citeturn18search0turn9view0 |

## Research Findings

Ниже — практики по уровням оптимизации (LLM/API, токены, orchestration, кэш, local/hybrid, infra, reliability, monitoring) с привязкой к тому, **где именно** в OpenClaw это можно реализовать.

### LLM/API costs

**Модельный выбор и ценовые «ступени».** На практике выгодно строить «ценовую лестницу» моделей уровня: дешево → средне → дорого, плюс отдельная «high-reliability» модель для SLO‑критичных задач. Исследования по routing/cascades (FrugalGPT, RouteLLM) показывают кратные снижения стоимости при сохранении качества за счет динамического выбора модели. citeturn7search0turn7search1turn7search25  

**Под OpenClaw это маппится напрямую**, потому что:  
— есть глобальные `agents.defaults.model.primary` и `agents.defaults.model.fallbacks`, и OpenClaw реально выполняет fallback при failover (после profile-rotation) на ошибки auth/rate limits/timeouts. citeturn3search0turn3search3  
— OpenClaw хранит состояние cooldown/disabled профилей в `auth-profiles.json`, использует экспоненциальный backoff и отдельно обрабатывает billing failures. Это важно: плохо подобранные fallbacks могут привести к «дорогому фолбэку по умолчанию» при любом transient‑сбое. citeturn3search0  

**Цены и экономика cached tokens (пример, чтобы калибровать ROI).**  
— OpenAI GPT‑5.2: $1.750/1M input и $0.175/1M cached input, output $14/1M (10× разница на input). citeturn11view0  
— Anthropic Sonnet 4.6 (≤200K): input $3/MTok, output $15/MTok, prompt caching read $0.30/MTok, write $3.75/MTok; при >200K все дорожает. citeturn13view0  
— Gemini 2.5 Pro: input $1.25/MTok при ≤200K и $2.50/MTok при >200K; output $10/MTok и $15/MTok соответственно; отдельная стоимость context caching и storage. citeturn2search1turn2search5  

**Batch API / async обработка.** Для задач, которые могут быть асинхронными (например, ночной дайджест, weekly отчеты, массовые преобразования), batch может уменьшить цену:  
— OpenAI явно пишет, что Batch API дает **50% экономии** на inputs/outputs для асинхронного выполнения до 24 часов. citeturn11view0  
— Anthropic на pricing-странице также отмечает «Save 50% with batch processing». citeturn13view0  
Под OpenClaw это обычно реализуется через cron isolated jobs (или внешнюю очередь), потому что cron уже отделяет точные/асинхронные задачи от main session и поддерживает delivery-контрол. citeturn8search2turn8search5  

**Long-context economics.** Если ваш OpenClaw‑workflow регулярно пересекает 200K prompt tokens, вы платите «премию за длинный контекст» у некоторых провайдеров (пример: Sonnet 4.6 и Gemini 2.5 Pro). Поэтому экономически правильно:  
— держать effective context <200K через pruning/compaction и retrieval из memory; citeturn5search3turn18search8turn16view0  
— если нужно «длинное чтение», выносить это в isolated job/subagent и возвращать в main session только краткий результат. citeturn8search2turn3search13  

### Token efficiency (контекст и промпты)

**Ключевая особенность OpenClaw:** системный промпт «OpenClaw-owned», стабильно структурирован и включает Tooling/Skills/Workspace/Runtime, а также инжектит bootstrap файлы каждый раз. citeturn14view0turn18search1  

Практически это означает, что «prompt compression» в OpenClaw — это не только «сжимать user prompt», а управлять тремя слоями:

1) **Tool schemas и tool list**:  
`/context detail` прямо помогает измерять вклад самых больших tool schemas. citeturn18search1  
Рычаги:  
— `tools.profile` (minimal/messaging/coding/full) и `tools.allow/deny`/`tools.byProvider` уменьшают доступные инструменты (и, как следствие, схему-обвязку), плюс снижают риск runaways. citeturn8search0turn18search1  

2) **Bootstrap injection**:  
— лимиты `agents.defaults.bootstrapMaxChars` (по умолчанию 20000) и `bootstrapTotalMaxChars` (по умолчанию 150000) позволяют «резать» инжектируемые файлы; OpenClaw рекомендует держать их короткими и предупреждает о стоимости. citeturn14view0turn18search1turn5search4  
— subagent sessions инжектят меньше файлов (AGENTS.md + TOOLS.md), а promptMode `minimal` режет еще больше секций system prompt. citeturn14view0turn3search13  

3) **История сессии и tool results**:  
— compaction суммаризирует старую историю в «compact summary entry» и оставляет свежие сообщения; это защищает от переполнения окна и уменьшает входной контекст. citeturn18search8turn4search1  
— session pruning умеет мягко/жестко подрезать `toolResult`, не трогая user/assistant сообщения; есть `cache-ttl` режим для Anthropic, чтобы после TTL не перекэшировать «толстый» tool baggage. citeturn5search3turn6search0  

**Group history injection** как скрытый пожиратель токенов.  
OpenClaw буферизует group history и может инжектить «сообщения с момента последнего ответа»; лимиты управляются `messages.groupChat.historyLimit` и переопределяются на уровне каналов/аккаунтов. citeturn4search2turn4search0turn19view1  

**Output length и stop conditions.**  
— OpenClaw’s model catalog поддерживает `params.maxTokens` (provider-specific) для модели, что дает «жесткую крышку» output. citeturn18search6turn19view0  
— OpenAI дополнительно рекомендует контролировать длину ответов через token caps/stop sequences/verbosity settings. citeturn18search16  

**Vision token cost**: для скриншот-heavy сценариев OpenClaw позволяет снизить `agents.defaults.imageMaxDimensionPx` (default 1200) для downscaling, что обычно снижает vision token usage. citeturn18search3  

### Agent workflow / orchestration

**Снижение ненужных tool calls через policy и «минимальные профили».** В OpenClaw инструментальная поверхность — часть system prompt и стоимости. Поэтому orchestration‑оптимизация начинается с политики инструментов: сначала минимальный профиль, затем расширение «по необходимости». citeturn8search0turn18search1  

**Cron vs heartbeat как cost-архитектура.**  
— Heartbeat предназначен для батчинга регулярных проверок (по умолчанию каждые 30m или 1h для Anthropic OAuth/setup-token), а cron — для точного расписания и изоляции контекста. citeturn18search17turn8search5  
— В cron isolated jobs можно задавать model/thinking overrides и delivery.mode (announce/webhook/none), что превращает cron в «дешевый pipeline executor» без загрязнения main session. citeturn8search2turn8search5  
— Cron имеет собственный retry backoff (30s, 1m, 5m, 15m, 60m) при последовательных ошибках — это важно, чтобы не устроить «пожарную» петлю повторов. citeturn3search1  

**Retry policy и стоимость повторов.**  
OpenClaw описывает retry policy для провайдеров каналов (например, Telegram/Discord): attempts 3, maxDelay 30s, jitter, retry_after и т.д. Это снижает число «повторных» прогонов и одновременно риск дублирования non-idempotent операций. citeturn3search4  

**Failover chains и истинная стоимость надежности.**  
Model failover в OpenClaw идет через: profile rotation → fallbacks; timeout/rate limit ошибки создают cooldown с эксп. backoff; billing failures могут выводить профиль из строя на часы. Это означает, что неправильно настроенная fallback-цепочка может:  
— увеличивать cost (прыжок на дорогую модель),  
— увеличивать latency (много попыток),  
— снижать reliability (дольше до успешного ответа). citeturn3search0turn3search3  

### Caching & reuse

**Provider-side prompt caching — базовая экономия.**  
— OpenAI: Prompt Caching «работает автоматически»; заявленные эффекты до 90% по input cost и до 80% по latency. citeturn1search14turn1search6  
— OpenClaw дополнительно адаптирует system prompt для cache‑стабильности: в секции времени теперь хранится только timezone без «динамических часов», а «текущее время» предлагается брать через `session_status`. Это улучшает шанс cache hits в агентных циклах. citeturn14view0turn18search1  
— Для Anthropic cacheRead/cacheWrite имеют разные тарифы/мультипликаторы и TTL, поэтому OpenClaw предлагает конкретные стратегии: cache‑ttl pruning и heartbeat cadence «чуть меньше TTL» (пример: 55m при 1h TTL), чтобы не платить за повторный cache write больших префиксов. citeturn6search2turn6search0turn1search3  

**Кэш embeddings для памяти.**  
В memorySearch есть embedding cache (SQLite), который уменьшает стоимость re-embed при переиндексации и обновлениях, особенно для «растущих» session transcripts. citeturn2search0turn6search1  

**Semantic cache и verified reuse (продвинутый уровень).**  
Если у вас много повторяемых запросов (пример: саппорт/FAQ/регламентные операции), semantic cache может резко уменьшить число LLM вызовов. Однако надежность «семантического совпадения» — риск. Работы вроде vCache исследуют надежность semantic prompt caching и попытки гарантировать ограничение ошибки. citeturn7search15turn7search19  
Практический вывод: semantic cache — high-leverage, но должен быть «SLO-aware» (guardrails, TTL, hit/miss policy, safe fallback на LLM). citeturn7search23turn15academia30  

### Local/offline/hybrid execution

**OpenClaw поддерживает кастомные провайдеры, включая local OpenAI-compatible endpoints**, что позволяет делать hybrid routing (local-first для простых задач, cloud для сложных). Конфиги в issues показывают, что можно задавать local provider с нулевой стоимостью input/output/cache. citeturn1search0turn3search3  

**Память и embeddings тоже можно удерживать локально:** OpenClaw описывает `memorySearch.provider = "local"` (без API usage) и auto-selection провайдера по ключам; в FAQ подчеркивается, что OAuth (например Codex) embeddings не покрывает — нужен отдельный key, если вы хотите OpenAI embeddings. citeturn6search4turn9view0turn6search1  

Ключевой принцип hybrid экономии: вы платите «дорогой модели» только за то, что действительно дает ROI (сложное reasoning, высокая точность, длинные документы), а «клей» (классификация, форматирование, короткие суммаризации, маршрутизация) перекладываете на local/cheap слой. Это соответствует выводам исследований по cascades/routing. citeturn7search0turn7search1  

### Infrastructure & deployment costs

OpenClaw — self-hosted gateway, поэтому к LLM cost добавляются **VPS/compute, storage/logging, observability и безопасность**. citeturn17search24turn8search6  

Практически значимые статьи:  
— Docker sandbox (если вы изолируете группы/сессии) может создавать overhead; OpenClaw поддерживает sandbox режимы (например non-main) для разделения DM vs group. citeturn3search15turn8search6  
— Логи/трейсы: OpenClaw имеет отдельные runbook‑разделы про logging; важно ограничивать уровень детализации в production, иначе observability может становиться заметной частью storage/IO расходов (эвристика; измеряется через объем логов и IO). citeturn8search6turn21view0  

### Reliability-cost tradeoff

Экономия, которая ломает reliability, почти всегда возвращается «вдвоем» через retries, ручной саппорт, и повторные прогоны.

Критичные механизмы надежности в OpenClaw, которые одновременно управляют cost:  
— retry policy (ограничение попыток/задержек), чтобы transient‑ошибки не превращались в бесконечные циклы; citeturn3search4  
— cron backoff и ограничение announce delivery retries/expiry, чтобы не было «залипания» пост-объявлений; citeturn3search1turn3search13  
— failover cooldowns и billing disables, которые предотвращают «долбежку» в один и тот же сломанный профиль. citeturn3search0  

Отдельный риск: **несоответствие ожиданий о том, какая модель реально используется** (например, subagent model overrides/настройки могут работать не так, как предполагалось) — это прямой риск неожиданных счетов. В репозитории есть баг-репорты о том, что `agents.defaults.subagents.model` не всегда применялся ожидаемо. citeturn17search4turn17search17  
Практический вывод: любые cost-стратегии, завязанные на subagents, должны иметь «детектор фактической модели» (лог/метрика) и kill switch. citeturn21view0turn5search1  

### Monitoring / FinOps

OpenClaw уже дает несколько встроенных «точек измерения»:  
— `/status` (сессия: модель, контекст, last tokens, а при API-key — оценка стоимости), `/usage off|tokens|full`, `/usage cost` (локальная агрегация из session logs). citeturn5search1turn21view0turn9view0  
— `openclaw status --usage` и `openclaw channels list` (usage snapshots от провайдера; можно отключать `--no-usage`). citeturn21view0turn9view0  
— `/context detail` (разложение prompt на tool schemas/skills/bootstrap). citeturn18search1  

Важно: usage tracking может дергать provider usage endpoints (это обычно низкий объем, но в строгих окружениях тоже учитывается). citeturn21view0turn9view0  

## Prioritized Recommendations

Ниже — приоритизированная таблица по **ROI = (Expected Savings × Confidence) / Effort** (качественная сортировка; диапазоны savings — типовые для агентных систем и должны подтверждаться вашим A/B). Наиболее «прибитые фактами» цифры — по caching и ценам провайдеров. citeturn11view0turn13view0turn1search14turn6search0  

| Rank | Recommendation | Expected Savings (%) | Impact on Quality | Impact on Latency | Implementation Effort | Risk | Confidence | Time to Implement | Prerequisites | How to Measure |
|---|---|---:|---|---|---|---|---|---|---|---|
| 1 | Максимизировать provider prompt caching + измерять cacheRead/cacheWrite/hit-rate, затем чинить «перекэширование после TTL» (cache‑ttl pruning + cadence) | 20–70% (input-heavy workloads) | Neutral/↑ | ↓ (часто) | Med | Low–Med | High | 1–7 дней | Включенная телеметрия `/status`/`/usage`, корректные model cost поля | cacheHit% (tokens), cost/run, cost after idle gap citeturn6search2turn6search0turn6search3turn1search14 |
| 2 | Включить `agents.defaults.contextPruning` (soft-trim/hard-clear toolResult) + настроить параметры | 15–50% | Neutral | ↓ | Low–Med | Low | High | 1 день | Понимать, какие tool outputs критичны | input tokens/run, toolResult chars kept, failure rate citeturn5search3turn18search1 |
| 3 | Ограничить tool surface: `tools.profile` + `tools.allow/deny` + `tools.byProvider` (минимум по умолчанию) | 10–35% | Neutral/↑ (меньше отвлечений) | ↓ | Low | Low | High | 1 день | Знать необходимые инструменты по сценариям | system prompt size, tool schema tokens, tool calls/run citeturn8search0turn18search1 |
| 4 | Урезать group history injection: `messages.groupChat.historyLimit`/per-channel `historyLimit` (0–20 вместо 50) | 5–30% | Neutral/↓ (если нужен полный контекст) | ↓ | Low | Low–Med | High | 1 день | Понимать требования групп | input tokens/run в группах, качество ответов на «контекстных» вопросах citeturn4search2turn4search0turn19view1 |
| 5 | Жестко задать `params.maxTokens` и «Short answers» policy для каналов; убрать verbosity | 5–25% | Neutral/↓ (если нужен long-form) | ↓ | Low | Low | High | 1 день | Согласованные форматы ответов | output tokens/run, P95 latency, CSAT/ручной скоринг citeturn18search6turn19view1turn18search16 |
| 6 | Сжать bootstrap файлы и лимиты `bootstrapMaxChars/bootstrapTotalMaxChars`; вынести детализацию в skills (read-on-demand) | 10–40% | Neutral/↑ | ↓ | Med | Med (можно «перерезать» важное) | Medium | 2–7 дней | `/context detail`, ревизия AGENTS/SOUL/TOOLS | bootstrap injected tokens, compaction frequency, “forgotten policy” incidents citeturn14view0turn18search1turn5search4 |
| 7 | Развести задачи на модели: cron isolated jobs и subagents с дешевыми моделями; escalation на сильную только при необходимости | 20–60% | Neutral (при хорошем router) | ↓/↑ | Med–High | Med | Medium | 1–4 недели | Категоризация задач, метрики качества | cost/task, escalation rate, pass@k по эвристическим проверкам citeturn8search2turn3search13turn7search1 |
| 8 | Зафиксировать fallback order по цене+SLO (не “дорогой фолбэк по умолчанию”), настроить профили/кулдауны | 5–20% | ↑ (меньше деградаций) | ↓/Neutral | Med | Low–Med | High | 2–7 дней | Понимание ошибок/лимитов, актуальные профили | failover frequency, avg attempts, cost on error bursts citeturn3search0turn3search3 |
| 9 | Удерживать long-context ниже порога >200k (pruning+compaction+RAG) или выносить long reads в isolated и возвращать summary | 10–50% (если часто >200k) | Neutral/↑ | ↓ | Med | Med | Medium | 1–2 недели | Частые long-context кейсы | доля запросов >200k, стоимость/1000 задач, quality on long docs citeturn13view0turn2search1turn5search3turn18search8 |
| 10 | Перевести memory embeddings на local/cheap, включить embedding cache, контролировать chunk sizing | 2–15% (или больше при heavy memory) | Neutral | ↓ | Med | Low–Med | Medium | 1–2 недели | Доступный local embeddings runtime | embeddings spend/day, indexing errors, recall quality citeturn2search0turn6search1turn9view0 |
| 11 | Сократить платные web_fetch/web_search: ограничить вызовы, кешировать результаты fetch/search, снижать глубину retrieval | 5–25% | Neutral/↓ (если нужен web) | ↓ | Med | Med | Medium | 1–2 недели | Логи tool calls | web tool calls/task, cache hit, correctness on web tasks citeturn9view0turn15search13turn15search3 |
| 12 | Внешний semantic cache (Redis/векторный) с guardrails (verified/TTL/SLO-aware) | 10–60% (на повторяемых запросах) | Neutral/↓ без верификации | ↓ | High | Med–High | Low–Med | 2–6 недель | Повторяемость запросов, infra для cache | hit rate, error from cache, rollback rate citeturn7search35turn7search15turn7search23 |

## Implementation Roadmap

### Quick Wins

**Цель за 1–3 дня:** «срезать» базовый токен‑burn и включить измеримость, не меняя архитектуру.

1) Включить видимость:  
— включить `/usage tokens` на ключевых сессиях (или как процесс: всегда включать при новых сессиях), регулярно смотреть `/usage cost` и `/status`. citeturn5search1turn21view0  
— добавить weekly выгрузку: `openclaw status --usage`, `openclaw channels list --no-usage` (если usage endpoints не нужны). citeturn21view0turn9view0  

2) Срезать контекст:  
— включить `agents.defaults.contextPruning` (начать с дефолтов, затем тюнить). Это почти всегда дает быструю экономию в агентных конвейерах, где много tool outputs. citeturn5search3  
— снизить `messages.groupChat.historyLimit` и/или per-channel historyLimit, особенно для шумных групп. citeturn4search2turn4search0turn19view1  

3) Срезать tool surface по умолчанию:  
— выставить `tools.profile` на «coding»/«messaging»/«minimal» (по ситуации) и явные deny на тяжёлые инструменты, которые не нужны постоянно. citeturn8search0turn18search1  

4) Поставить жесткие caps на output и «краткость»:  
— `params.maxTokens` на модели в `agents.defaults.models` и «Short answers only / Keep answers brief» на каналы/группы где релевантно (OpenClaw поддерживает per-group systemPrompt). citeturn18search6turn19view1  

5) Heartbeat hygiene:  
— отключить `agents.defaults.heartbeat.includeReasoning` (если включали) и сократить HEARTBEAT.md до короткого чек-листа; OpenClaw рекомендует «tiny HEARTBEAT.md» и задает default prompt. citeturn18search17turn3search5  

**Как откатить:**  
Каждый из этих шагов — конфиговый. Откат: вернуть прежние значения ключей в `~/.openclaw/openclaw.json` (конфиг строгий и валидируется по schema). citeturn8search6turn15search21  

### Medium-Term Improvements

**Цель за 1–4 недели:** внедрить «cheap-first, expensive-last» и стабилизировать caching/TTL.

1) Модельный роутинг через cron isolated jobs:  
— все регулярные/плановые задачи (дайджесты, отчеты, проверки) запускать как cron isolated jobs с model override: дешевые рутины — на cheap, «аналитика» — на strong. citeturn8search2turn8search5  
— delivery.mode для cron настроить так, чтобы не слать лишнее (announce vs none), и не дублировать сообщения. citeturn8search2turn3search1  

2) Failover цепочки и профили:  
— упорядочить fallbacks по стоимости/качеству и «режиму аварии» (например, дешевый стабильный фолбэк для продакшн‑ответов). citeturn3search0turn3search3  

3) Caching TTL стратегия (особенно если Anthropic):  
— включить cache‑ttl pruning; подобрать ttl под фактическую cache TTL; затем подобрать heartbeat cadence («чуть меньше TTL») **только если** экономия от предотвращения cache-write больше, чем цена heartbeat. citeturn6search0turn6search2turn18search17  

4) Перепаковка bootstrap:  
— превратить AGENTS/SOUL/TOOLS в «короткие правила» + ссылки на skills (которые читаются on-demand), и проверить `/context detail`, что доля bootstrap токенов упала. citeturn14view0turn18search1  

### Advanced / High-Leverage Optimizations

**Dynamic routing / confidence-based escalation.**  
На уровне исследовательских практик: RouteLLM/FrugalGPT показывают, что роутер может направлять простые запросы на слабую модель, а «сложные» — на сильную, получая кратные savings. citeturn7search1turn7search0turn7search25  
В OpenClaw это реализуется тремя способами (по возрастанию инженерки):  
1) эвристики/правила (тип задачи → модель) через cron isolated, subagents и вручную определенные «профили задач»; citeturn8search2turn3search13  
2) lightweight router (дешевая модель классифицирует запрос/оценивает риск/complexity) → выбирает primary модель;  
3) обучение/калибровка роутера на ваших данных (RouteLLM-подход). citeturn7search17turn7search13  

**Semantic caching с надежностью.**  
Использовать semantic cache (например, Redis semantic cache интерфейсы) для повторяемых запросов, но добавлять «верификацию»/guardrails (vCache-подход) и SLO-aware fallback на LLM. citeturn7search35turn7search15turn7search23  

**Local/cloud hybrid.**  
Свести к нулю стоимость «клеевых» задач, отправляя их в local provider (OpenAI-compatible endpoint) и сохраняя cloud только для «IQ». В OpenClaw это опирается на `models.providers` и allowlist моделей. citeturn1search0turn3search3  

### Suggested Implementation Roadmap

**30 дней (основа FinOps + quick wins).**  
Роли: 1 инженер/опс + 1 владелец продукта (качество).  
— Включить метрики (`/usage`, `/status`, `/context detail`), pruning, tool profile ограничения, history limits, output caps. citeturn21view0turn5search3turn8search0turn4search2  
Ожидаемая cumulative savings: типично 20–40% при input-heavy агентных сценариях (оценка; подтвердить A/B метриками ниже).

**60 дней (модельный роутинг и TTL).**  
Роли: инженер + исследователь/ML (для роутинга).  
— Cron-isolated для автоматизаций, model overrides, fallback order; caching TTL стратегия. citeturn8search2turn3search0turn6search0  
Ожидаемая cumulative savings: +10–30% сверху, если раньше сильная модель обрабатывала «все подряд».

**90 дней (high-leverage: semantic cache + hybrid).**  
Роли: инженер платформы + SRE/безопасность + ML.  
— semantic cache (guarded), локальные embeddings/local inference для low-risk; budget-aware router; kill switches. citeturn7search15turn6search1turn7search1  
Ожидаемая cumulative savings: сильно зависит от повторяемости и доли low-risk задач; диапазон часто 30–70% суммарно, но требует строгой валидации качества.

## Measurement Plan

### Система метрик (daily/weekly)

**Основные cost-метрики (обязательные):**  
1) *Cost per successful task* (USD/успешный workflow) — главный KPI. Источник: `/usage cost` + ваш task outcome. citeturn5search1turn21view0  
2) *Tokens per run* (input/output/cacheRead/cacheWrite) и *cacheHit%* (token-based), отдельно по моделям и по типам задач. OpenClaw умеет показывать cacheRead/cacheWrite и last tokens на `/status`, если стоимость описана в модели. citeturn5search1turn6search3turn6search2  
3) *Retries per workflow* (каналы + LLM failover): число повторов/ошибок/таймаутов. citeturn3search4turn3search0  
4) *Failure recovery cost*: стоимость «починки» (повторные прогоны, ручные вмешательства). Практически: события “rerun”, “failover invoked”, “manual retry”. citeturn3search0turn3search1  
5) *P50/P95 latency* per workflow и per LLM call (если есть). Prompt caching часто улучшает latency. citeturn1search14turn1search6  

**Quality proxy metrics (минимально нужные):**  
— *Task pass rate* (успех/неуспех по чек-листу);  
— *Escalation rate* (доля запросов, ушедших на «дорогую» модель);  
— *Regression set* из 50–200 типичных задач (ручная оценка или автоматически проверяемые результаты). Подход соответствует практике оценки роутеров (RouteLLM/FrugalGPT). citeturn7search1turn7search0  

**Anomaly detection и бюджетные kill switches:**  
— алерт: cost/day > baseline×X или cacheHit% резко упал, или доля failover/timeout выросла. Cache hit rate — ключевой leading indicator. citeturn6search3turn6search8turn21view0  
— kill switch: временно переключить primary model на «дешевую и стабильную», отключить web_fetch/Firecrawl, ограничить tools до minimal, остановить heartbeat. Это реализуется конфигом. citeturn8search0turn18search17turn9view0  

### Дизайн A/B тестов для оптимизаций

**Принцип:** A/B нужно делать на уровне **workflow**, а не отдельного сообщения, иначе вы не поймаете стоимость retries/ошибок.

1) **Randomized assignment**: по sessionKey или по пользователю (если SMB).  
2) **Стабильный период**: минимум 3–7 дней или N=200+ workflow (что наступит раньше), потому что cost/latency имеют тяжелые хвосты. (Эвристика; подтверждается наблюдением распределений.)  
3) **Primary endpoints:** cost per successful task, success rate, P95 latency.  
4) **Guardrail endpoints:** failover rate, retry rate, «bad output» incidents (ручной тэг).  
5) **Rollback rule:** если success rate падает >Δ или P95 latency растет >Δ, откат.

## Final “Best Proposals”

Ниже — 10 предложений «максимальной ценности» в формате Proposal → Why → savings → tradeoffs → implementation notes → validation checklist.

### Proposal: Сделать prompt caching «центральной дисциплиной» (cache-first operations)

**Why it matters.** В OpenClaw большая часть input — повторяющиеся префиксы (system prompt + tools + bootstrap + часть истории). У OpenAI cached input на GPT‑5.2 в 10 раз дешевле, а OpenAI заявляет до 90% экономии input при caching. citeturn11view0turn1search14turn18search1  

**Expected savings.** 20–70% (зависит от доли cached префикса и hit rate).  

**Tradeoffs.** Требует дисциплины: стабильный префикс, контроль TTL (особенно Anthropic, где write дороже). citeturn1search3turn6search0  

**Implementation notes.**  
— включить измерение cacheRead/cacheWrite;  
— включить cache‑ttl pruning для Anthropic;  
— выставить heartbeat cadence только там, где выгодно держать кэш теплым. citeturn6search2turn6search0turn18search17  

**Validation checklist.** cacheHit% (tokens) вырос, cacheWrite spikes после idle уменьшились, cost/run снизился, успех задач не упал.

### Proposal: Включить session pruning как «страховку от tool-output инфляции»

**Why it matters.** Tool results остаются в истории и могут раздувать context; OpenClaw умеет подрезать только `toolResult` (без изменения user/assistant сообщений). citeturn5search3turn18search1  

**Expected savings.** 15–50% на tool-heavy workflows.  

**Tradeoffs.** Риск: если вырежете важные части tool output, качество упадет.  

**Implementation notes.** Начать с дефолтов pruning и добавить исключения для критичных инструментов. citeturn5search3turn8search0  

**Validation checklist.** input tokens/run снизились, число «попроси повторить команду» не выросло, success rate стабильный.

### Proposal: Ограничить tool surface (минимальный профиль по умолчанию)

**Why it matters.** Tools влияют на prompt двумя способами: список инструментов и JSON schemas, которые входят в контекст. citeturn18search1turn8search0  

**Expected savings.** 10–35% + снижение risk поверхности.  

**Tradeoffs.** Иногда меньше «автоматичности», нужно разрешать инструменты точечно.  

**Implementation notes.** `tools.profile` + deny тяжелых инструментов; включать browser/web_fetch только для отдельных агентов/провайдеров через `tools.byProvider`. citeturn8search0turn19view0  

**Validation checklist.** system prompt tokens уменьшились; tool calls стали более целевыми.

### Proposal: Порог 200K tokens как «красная линия» стоимости long-context

**Why it matters.** У Anthropic и Gemini официально есть скачок цены после 200K prompt tokens. citeturn13view0turn2search1  

**Expected savings.** 10–50% в сценариях, где вы часто пересекаете порог.  

**Tradeoffs.** Меньше «сырая история», больше reliance на память/summary.  

**Implementation notes.** compaction + pruning + «длинные чтения в isolated job», возвращать summary. citeturn18search8turn5search3turn8search2  

**Validation checklist.** доля запросов >200K падает; стоимость «на документ» падает; качество summary приемлемо.

### Proposal: Cron isolated jobs как cost‑контейнер для автоматизаций

**Why it matters.** Cron позволяет изолировать контекст и задавать model/thinking overrides; delivery можно выключить или сделать announce. citeturn8search2turn8search5  

**Expected savings.** 10–30% на автоматизациях + меньше загрязнение main session.  

**Tradeoffs.** Нужно дисциплинированно проектировать jobs и delivery.  

**Implementation notes.** Все периодические отчеты перенести в cron isolated; main session оставить для диалога. citeturn8search5turn3search1  

**Validation checklist.** main session input tokens снижаются; cron cost/job контролируемый; меньше compaction в main.

### Proposal: Жесткое ограничение output (maxTokens + «short answers»)

**Why it matters.** Output особенно дорог на некоторых моделях; плюс длинный output провоцирует follow-up и увеличивает общий cost. OpenClaw поддерживает `params.maxTokens`, а OpenAI имеет отдельные рекомендации по контролю длины ответов. citeturn18search6turn18search16  

**Expected savings.** 5–25%.  

**Tradeoffs.** Может ухудшить UX там, где нужен long-form.  

**Implementation notes.** Разные caps по каналам; «короткий ответ + offer details on request».  

**Validation checklist.** output tokens/run падают; доля «попроси подробнее» не растет критически; CSAT стабилен.

### Proposal: Локальные embeddings и embedding cache для памяти

**Why it matters.** Memory search может тратить embeddings keys; есть embedding cache в SQLite. citeturn9view0turn2search0turn6search1  

**Expected savings.** 2–15% (а в memory-heavy сценариях больше).  

**Tradeoffs.** Local embeddings могут быть менее качественными, нужен контроль recall.  

**Implementation notes.** Включить embedding cache, при необходимости `memorySearch.provider="local"` и fallback policy. citeturn2search0turn6search4  

**Validation checklist.** embeddings spend/day падает; качество memory recall приемлемо.

### Proposal: Урезать платные web_fetch/web_search и добавить кэш

**Why it matters.** OpenClaw перечисляет web_search и web_fetch (Firecrawl) как потенциально платные. citeturn9view0turn15search13  

**Expected savings.** 5–25% в web-heavy сценариях.  

**Tradeoffs.** Меньше «актуальности» или надежности веб-извлечения.  

**Implementation notes.** Ввести policy: «search only if needed», кэшировать результаты fetch/search на TTL, ограничить depth. citeturn15search3turn7search23  

**Validation checklist.** число web tool calls/task падает; качество ответов с web не деградирует.

### Proposal: Dynamic routing (router) с escalation на сильную модель

**Why it matters.** RouteLLM/FrugalGPT показывают 2× и больше экономии при роутинге без потери качества. citeturn7search1turn7search0turn7search25  

**Expected savings.** 20–60% (если много «простых» запросов).  

**Tradeoffs.** Нужна калибровка качества, риск ошибок роутера.  

**Implementation notes.** Начать с правил (task-based assignment), затем перейти к роутеру на данных. В OpenClaw технически это реализуется через выбор модели для isolated job/subagent и возврат результата. citeturn8search2turn3search13  

**Validation checklist.** escalation rate соответствует ожиданиям; quality proxy метрики не падают.

### Proposal: SLO-aware guardrails против runaway sessions + бюджетные kill switches

**Why it matters.** Failures/retries/loops — прямой множитель стоимости. OpenClaw уже имеет retry/backoff, subagent ограничения и инструменты остановки; но budget-aware слой обычно нужно добавить операционно. citeturn3search4turn17search2turn21view0  

**Expected savings.** 5–20% (через снижение «пожаров») + повышение надежности.  

**Tradeoffs.** Иногда «раньше остановим» задачу и попросим подтверждение.  

**Implementation notes.** Лимиты на время/кол-во шагов/подзадач, алерты на всплески, режим деградации (минимальный tool profile + дешевая модель). citeturn8search0turn3search0turn18search17  

**Validation checklist.** cost spike incidents ↓, retries ↓, P95 latency ↓, success rate стабильный.