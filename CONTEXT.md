# CONTEXT.md — Projeto de Brinquedo Digital de Construção 3D

**Documento de transferência de contexto para outras IAs**

Versão: 1.0  
Data: 14/11/2026  
Idioma de trabalho: Português (Brasil)

---

# 1. Visão do projeto

O projeto é um brinquedo digital de construção tridimensional para tablets Android, destinado principalmente ao público infantil e ao uso em ambiente escolar.

A proposta é oferecer uma experiência de construção livre, com peças geométricas que podem ser posicionadas, combinadas e organizadas sobre uma plataforma.

A inspiração vem da liberdade de construção de brinquedos físicos de montar e de jogos como Minecraft e Stardew Valley, mas o produto deve ter identidade visual própria.

**Não é:**

- Um editor técnico de modelagem 3D.

- Um jogo baseado em missões.

- Um jogo com pontuação ou progressão obrigatória.

- Uma cópia de LEGO ou Minecraft.

**É:** um brinquedo digital de construção, intuitivo, acessível e convidativo, que estimula criatividade e experimentação.

# 2. Público e plataforma

- Público principal: crianças em idade escolar.

- Uso previsto: tablets compartilhados por vários alunos.

- Dispositivo de referência: tablet Android com 4 GB de RAM.

- Orientação: paisagem (landscape).

- Referência de viewport: 1920 × 1200 (16:10).

- Funcionamento offline.

- Sem login, contas ou identificação de alunos.

- Sem dependência de serviços em nuvem.

A interface deve ser responsiva e não pode depender exclusivamente da resolução de referência.

# 3. Tecnologia e ambiente de desenvolvimento

Tecnologia aprovada:

- Godot 4.x.

- GDScript.

- Renderizador Mobile.

- Exportação Android.

Ambiente verificado no início do projeto:

| Componente       | Versão / situação           |
| ---------------- | --------------------------- |
| Godot            | 4.7.2 stable                |
| Renderer         | Forward Mobile              |
| Java             | OpenJDK 21.0.12 LTS         |
| Android SDK      | `D:\Android`                |
| ADB              | Operacional                 |
| Export templates | Instalados para Godot 4.7.2 |

O desenvolvimento é realizado no PC Windows.

# 4. Organização do trabalho com agentes

O usuário atua como arquiteto e responsável pelas decisões de produto.

Fluxo de desenvolvimento:

- ChatGPT: arquitetura, especificações, decisões e revisão crítica.

- Antigravity: ambiente de desenvolvimento e execução.

- Argon: agente principal de implementação e coordenação.

- Hydrogen: subagentes especializados convocados pelo Argon.

O usuário mantém uma única janela de conversa com o Argon. Portanto, o Argon já possui o histórico das fases anteriores.

**Orientação para futuras especificações:**

Não repetir toda a arquitetura e o histórico em cada prompt.

Preferir:

1. Referenciar decisões e fases já aprovadas.

2. Pedir inspeção do código atual.

3. Especificar apenas o escopo da fase em andamento.

4. Reforçar restrições importantes.

5. Exigir testes de regressão.

6. Pedir relatório dos arquivos alterados e dos testes executados.

7. Determinar que o Argon pare ao final da fase e aguarde aprovação do usuário.

O Argon pode delegar tarefas aos Hydrogen, mas continua responsável pela revisão e integração.

O desenvolvimento ocorre em fases pequenas. Nenhuma fase seguinte deve começar sem validação do usuário.

# 5. Conceito de construção

O usuário constrói sobre uma plataforma plana e delimitada.

As peças devem:

- Encaixar em uma grade modular invisível.

- Ter auxílio de encaixe magnético (snap).

- Apoiar na plataforma ou em outras peças.

- Não atravessar outras peças.

- Não flutuar sem suporte.

- Permanecer dentro dos limites da plataforma.

A grade define posições válidas. O snap ajuda a encontrar essas posições, mas nunca pode ignorar as regras de construção.

Não implementar simulação física complexa sem necessidade.

## 5.1 Unidade e grade

Decisão arquitetural aprovada:

- X: passo de 1 unidade.

- Z: passo de 1 unidade.

- Y: passo de 0,25 unidade.

A coordenada lógica deve ser inteira (`Vector3i`), evitando depender de coordenadas de ponto flutuante para as regras de posicionamento.

Isso permite trabalhar com peças finas, como placas e pranchas, sem erros de alinhamento.

## 5.2 Plataforma

- Plataforma inicial: 8 × 8 unidades.

- Superfície plana.

- Limites discretos.

- Sem paredes.

- Sem expansão no MVP.

A expansão futura poderá ser considerada, mas não deve ser antecipada sem necessidade.

# 6. Catálogo de peças

As quatro peças iniciais aprovadas são:

| Identificador  | Dimensões preliminares |
| -------------- | ---------------------- |
| `cube`         | 1 × 1 × 1              |
| `long_block`   | 2 × 1 × 1              |
| `square_plate` | 2 × 2 × 0,25           |
| `ramp`         | 2 × 1 × 1              |

As dimensões especiais e a geometria exata devem respeitar a implementação aprovada e os dados atuais do catálogo.

Não adicionar novos tipos de peças sem aprovação.

## 6.1 Forma e cor

Uma decisão importante de produto:

**Forma e cor são escolhas independentes.**

A criança escolhe a forma e a cor separadamente.

Não criar entradas duplicadas no catálogo para representar cada combinação de forma e cor.

A cor selecionada deve ser aplicada às novas peças criadas.

A mudança de cor de peças já posicionadas não foi aprovada como requisito da Fase 3.

# 7. Identidade visual

A direção visual aprovada é:

- Aparência de brinquedo físico bem produzido.

- Infantil, mas não excessivamente infantilizada.

- Bordas suaves e chanfros discretos nas peças.

- Materiais foscos.

- Cores agradáveis.

- Iluminação suave.

- Sombras de contato.

- Plataforma e fundo simples.

- Boa leitura visual e pouco ruído.

A aparência atual das peças 3D foi aprovada pelo usuário.

**ATENÇÃO: não modificar a geometria das peças 3D sem nova autorização.**

Houve uma correção importante de entendimento:

O usuário pediu cantos arredondados, mas esclareceu que a mudança deve ocorrer exclusivamente na BANDEJA DE SELEÇÃO.

Portanto:

- Peças 3D: manter exatamente a aparência atual.

- Bandeja: cartões e áreas dos itens podem ter cantos arredondados.

- Não alterar malhas, proporções, chanfros, materiais ou formatos das peças.

# 8. Câmera

Decisões aprovadas:

- Câmera isométrica inicial.

- Ângulo fixo.

- Rotação da câmera em passos de 90° por botões.

- Zoom por gesto de pinça.

- Zoom também pode ter controles na interface.

- Botão de recentralização.

- Não permitir que gestos de construção movimentem acidentalmente a câmera.

Câmera livre é possibilidade futura, fora do MVP.

# 9. Interação de construção

## 9.1 Bandeja e estoque

- Bandeja localizada à esquerda.

- Aproximadamente 20% da largura como referência inicial.

- Pode ser recolhida.

- Estoque infinito.

- Arrastar uma peça da bandeja cria uma nova instância.

- A peça original permanece disponível na bandeja.

## 9.2 Arrastar e posicionar

Fluxo esperado:

1. Usuário pressiona uma peça da bandeja.

2. Uma nova instância aparece como preview.

3. O preview acompanha o ponteiro ou toque.

4. O sistema avalia a posição continuamente.

5. A posição válida recebe indicação verde.

6. A posição inválida recebe indicação vermelha.

7. Ao soltar, uma posição válida é confirmada.

8. Uma posição inválida é cancelada sem deixar uma peça indevida.

A interação deve funcionar com mouse no PC e toque no Android.

A arquitetura deve permitir adicionar posteriormente outro método, como selecionar a peça e tocar no destino.

## 9.3 Preview durante arraste

A peça deve manter sua cor e aparência originais durante o arraste.

O verde e o vermelho são indicadores de validade, não cores que devem substituir o material da peça.

Não deixar a peça inteira verde ou vermelha.

## 9.4 Seleção e edição

Funcionalidades implementadas ou previstas:

- Selecionar peça posicionada.

- Rotacionar.

- Apagar.

- Desfazer.

- Refazer.

### Rotação

Comportamento expressamente aprovado:

**Cada clique gira a peça selecionada em exatamente 90 graus.**

- Rotação em torno do eixo vertical.

- Quatro cliques completam 360°.

- A posição resultante precisa ser validada.

- Se for inválida, manter a rotação e posição anteriores.

Não implementar rotação contínua ou incrementos diferentes sem autorização.

# 10. Arquitetura lógica

A arquitetura deve manter separação entre:

- Catálogo e definições das peças.

- Sistema de posicionamento.

- Estado da construção.

- Controlador de interação.

- Controlador da câmera.

- Interface.

- Apresentação visual.

- Persistência.

Regras de construção não devem depender da interface ou da câmera.

O estado lógico da construção deve ser a fonte de verdade, e não a hierarquia de nós da cena 3D.

O projeto deve favorecer dados declarativos, posicionamento determinístico e baixo custo de execução.

# 11. Histórico das fases

## Fase 0 — Inspeção e planejamento técnico

< status: concluída >

O Argon inspecionou o ambiente e apresentou o plano técnico.

Constatações:

- Workspace inicialmente limpo.

- Godot 4.7.2 disponível.

- Ambiente Java e Android SDK operacional.

- Templates Android instalados.

- Nenhum tablet conectado via ADB naquele momento.

Riscos identificados:

1. Peças com altura 0,25 exigem subdivisão vertical da grade.

2. Arraste em câmera ortográfica exige resolver a altura usando interseção com superfícies e plano da plataforma.

3. Android ainda precisava de validação em hardware real.

Decisão: iniciar Fase 1 com viewport de referência 1920 × 1200, plataforma 8 × 8 e quatro peças estáticas.

## Fase 1 — Protótipo visual e câmera

< status: concluída e validada pelo usuário >

Implementações reportadas:

- Cena principal.

- Plataforma 8 × 8.

- Catálogo inicial.

- Malhas procedurais.

- Materiais foscos.

- Iluminação e sombras.

- Câmera isométrica.

- Rotação de câmera em passos de 90°.

- Zoom e recentralização.

- Bandeja provisória.

- Interface inicial.

Arquivos reportados:

- `project.godot`

- `scripts/core/piece_catalog.gd`

- `scripts/visuals/toy_mesh_builder.gd`

- `scripts/visuals/theme_visuals.gd`

- `scripts/controllers/platform_controller.gd`

- `scripts/controllers/camera_controller.gd`

- `scripts/ui/construction_ui.gd`

- `scripts/core/construction_workspace.gd`

- `scenes/main/construction_workspace.tscn`

- `tests/test_phase1.gd`

Testes reportados:

- Suíte automatizada aprovada.

- Inicialização no PC pelo renderizador Mobile.

- Capturas em diferentes ângulos.

Validação do usuário:

- Gostou das bordas arredondadas e do aspecto infantil.

- Considerou a interface provisória e sujeita a melhorias futuras.

- Aprovou a direção visual das peças.

## Fase 2 — Construção e posicionamento

< status: concluída e validada pelo usuário >

Implementações reportadas:

- Grade lógica com `Vector3i`.

- Posicionamento determinístico.

- Snapping.

- Verificação de limites.

- Verificação de colisões.

- Verificação de suporte.

- Tratamento especial da geometria da rampa.

- Instâncias infinitas vindas da bandeja.

- Preview durante arraste.

- Indicadores de validade.

- Integração com o estado da construção.

Arquivos reportados:

- `scripts/core/placed_piece_data.gd`

- `scripts/core/placement_system.gd`

- `scripts/core/construction_manager.gd`

- `scripts/controllers/interaction_controller.gd`

- Alterações em `piece_catalog.gd`, `theme_visuals.gd`, `construction_ui.gd` e `construction_workspace.gd`.

- `tests/test_phase2.gd`

Testes reportados:

- Testes de limites, colisão, suporte, altura, rampa, arraste, commit e cancelamento.

- Regressão da Fase 1 aprovada.

- Inicialização no PC aprovada.

Validação do usuário:

- Gostou do funcionamento.

- Solicitou que a peça mantenha sua própria cor durante o arraste, em vez de ficar toda verde.

Essa correção foi incorporada ao escopo da Fase 3.

## Fase 3 — Catálogo e ferramentas

< status: concluída e validada pelo usuário >

Implementações reportadas:

- Separação entre seleção de forma e cor.

- Seleção de peças posicionadas.

- Rotação de 90°.

- Exclusão.

- Undo/redo.

- Melhoria da bandeja.

- Preview preservando a aparência da peça.

A implementação foi considerada concluída e aprovada pelo usuário.

**Observação:** a conversa não contém o relatório detalhado dos arquivos e testes da Fase 3. A próxima IA deve inspecionar o projeto atual antes de afirmar detalhes específicos dessa implementação.

# 12. Fase atual — Fase 4

## Galeria e persistência

A Fase 4 foi especificada, mas ainda não foi enviada ao Argon.

Objetivo: implementar projetos independentes e armazenamento local.

Funcionalidades esperadas:

- Criar projeto.

- Abrir projeto.

- Renomear projeto.

- Excluir projeto.

- Retornar à galeria.

- Nomes automáticos: Construção 1, Construção 2 etc.

- Salvamento automático.

- Restauração do estado ao reabrir.

Armazenamento:

- Local.

- Offline.

- Sem login.

- Sem nuvem.

- Formato estruturado e legível, preferencialmente JSON.

- Dados lógicos das peças, não uma cena 3D opaca.

Cada projeto deve preservar:

- ID.

- Nome.

- Versão do formato.

- Data de criação.

- Data de modificação.

- Lista de peças.

- Tipo, posição, rotação e cor de cada peça.

Deve haver validação básica dos dados ao carregar.

Dados inválidos não podem causar crash nem sobrescrever silenciosamente um projeto.

Escrita de arquivos deve reduzir o risco de perda em encerramentos inesperados, preferencialmente com estratégia atômica.

A galeria deve ser simples, adequada a crianças e não se transformar em gerenciador de arquivos.

### Ajuste visual incluído na Fase 4

Apenas a bandeja de seleção pode receber cartões com cantos arredondados.

**Não alterar as peças 3D. Sua aparência atual está aprovada.**

### Regras de trabalho para a Fase 4

- Inspecionar o código atual.

- Preservar as funcionalidades das fases anteriores.

- Criar testes.

- Rodar todas as suítes anteriores.

- Testar o fluxo completo de galeria para construção no PC.

- Não afirmar que Android foi testado sem teste real.

- Parar ao terminar a Fase 4.

- Aguardar aprovação do usuário antes de começar a Fase 5.

# 13. Fora do MVP

Não implementar sem aprovação:

- Contas ou perfis de alunos.

- Identificação de estudantes.

- Nuvem ou sincronização online.

- Multiplayer.

- Missões, pontuação ou progressão.

- Novos tipos de peças.

- Plataforma expansível.

- Câmera livre.

- Ferramentas avançadas.

- Duplicação de peças.

- Compartilhamento de projetos.

# 14. Fase 5 — Acabamento e desempenho

A Fase 5 foi planejada inicialmente como etapa de acabamento e desempenho, mas ainda não possui especificação final aprovada.

Deverá considerar:

- Testes no tablet Android real.

- Desempenho e memória.

- Ajustes finais de interface.

- Refinamento de usabilidade.

- Verificação do fluxo completo.

Não iniciar automaticamente. Primeiro validar a Fase 4 e definir o escopo da Fase 5 com o usuário.

# 15. Preferências do usuário para colaboração

O usuário prefere:

- Português nas conversas e documentos de arquitetura.

- Respostas objetivas, sem excesso de explicações.

- Uma decisão ou pergunta por vez.

- Não receber questionários extensos.

- Prompts claros e precisos para o Argon.

- Identificadores, nomes de arquivos e código em inglês.

- Implementação incremental.

- Validação prática antes de avançar.

- Evitar abstrações e funcionalidades prematuras.

- Evitar que agentes inventem requisitos.

- Evitar reescrever sistemas já aprovados.

O usuário é o responsável pelas decisões de produto. A IA deve explicar implicações e sugerir soluções, mas não tomar decisões de escopo silenciosamente.

# 16. Orientações para a próxima IA

Ao assumir o projeto:

1. Leia este documento integralmente.

2. Peça ou inspecione o estado atual do workspace.

3. Verifique os arquivos reais antes de assumir que a implementação corresponde aos relatórios.

4. Diferencie claramente decisões aprovadas, implementações reportadas e funcionalidades ainda pendentes.

5. Não altere o visual aprovado das peças 3D.

6. Preserve a distinção entre forma e cor.

7. Respeite a rotação de 90° por clique.

8. Não pule fases.

9. Não implemente funcionalidades fora do escopo aprovado.

10. Aguarde a validação do usuário antes de avançar.

**Princípio central:** o objetivo é construir um brinquedo digital de construção agradável, intuitivo e confiável para crianças, não um editor 3D tecnicamente sofisticado.
