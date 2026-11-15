# Projeto --- Brinquedo Digital de Construção 3D

## Documento de visão e arquitetura inicial (MVP)

**Status:** concepção inicial consolidada\
**Público:** crianças em ambiente escolar\
**Plataforma-alvo:** tablets Android\
**Dispositivo de referência:** tablet de 10 polegadas, orientação
paisagem\
**Motor:** Godot 4.x, renderizador Mobile\
**Idioma do código:** inglês\
**Idioma da documentação e comunicação com o usuário:** português

------------------------------------------------------------------------

## 1. Instruções para o Argon

Você é o orquestrador técnico do projeto. Coordene os subagentes
Hydrogen quando isso ajudar a dividir tarefas, mas mantenha uma visão
única da arquitetura e das decisões.

### Regras de trabalho

1.  **Leia e inspecione o projeto existente antes de alterar arquivos.**
    Não presuma que uma estrutura, cena ou sistema já existe.
2.  Trabalhe em fases pequenas e verificáveis. Não implemente o
    aplicativo inteiro em uma única rodada.
3.  Código, nomes de classes, funções, variáveis, arquivos e
    identificadores devem estar em **inglês**.
4.  Seja sucinto nas respostas. Informe arquivos alterados, decisões
    relevantes, testes executados e problemas encontrados.
5.  Não invente requisitos nem complete lacunas importantes
    silenciosamente. Quando uma decisão de produto ou uma ambiguidade
    técnica bloquear a implementação, apresente uma recomendação curta e
    peça aprovação.
6.  Preserve decisões já aprovadas neste documento. Se encontrar
    conflito técnico real, explique o conflito antes de mudar a direção.
7.  Não adicione funcionalidades fora do MVP por iniciativa própria.
8.  Não use serviços online, login ou dependências de internet para
    funções essenciais.
9.  Após cada fase, execute os testes possíveis e apresente evidências
    objetivas. Não declare algo como funcional sem testar.
10. Antes de começar a fase seguinte, aguarde a validação do usuário
    quando a fase produzir algo visual ou interativo que precise ser
    experimentado.

### Uso dos subagentes

-   Delegue tarefas delimitadas aos Hydrogen (por exemplo: investigação
    de renderização, protótipo de câmera ou revisão de persistência).
-   Dê a cada subagente contexto suficiente e uma tarefa com resultado
    verificável.
-   O Argon continua responsável por integrar o trabalho, revisar o
    código e garantir consistência.
-   Evite delegar em paralelo alterações sobre os mesmos arquivos.

------------------------------------------------------------------------

## 2. Visão do produto

Criar um brinquedo digital de construção tridimensional para crianças. A
criança escolhe peças geométricas e monta livremente estruturas sobre
uma plataforma, com posicionamento assistido e encaixe magnético.

O produto deve transmitir a sensação de manipular peças físicas de um
brinquedo de montar. Não deve parecer um editor técnico de objetos 3D
nem depender de missões, pontuação ou progressão para ser divertido.

### Princípios

-   Construção livre e intuitiva.
-   Manipulação adequada a telas touch.
-   Peças com aparência de brinquedos físicos.
-   Interface simples, com baixa sobrecarga visual.
-   Regras espaciais consistentes: peças não atravessam umas às outras.
-   Funcionamento offline.
-   Desempenho adequado a tablets Android modestos.

### Fora do escopo do primeiro MVP

-   Exploração de um mundo ou personagem controlável.
-   Missões, pontuação, vidas ou progressão educativa.
-   Compartilhamento online ou sincronização em nuvem.
-   Contas, login ou identificação individual de alunos.
-   Temas visuais múltiplos.
-   Câmera livre.
-   Duplicação de peças já colocadas.
-   Modelagem livre ou ferramentas avançadas de edição.

------------------------------------------------------------------------

## 3. Decisões de produto aprovadas

### 3.1 Plataforma e orientação

-   Android, com prioridade para tablets.
-   Orientação paisagem (landscape).
-   Tablet de 10 polegadas como dispositivo de referência.
-   Interface responsiva: não fixar dimensões em pixels como se houvesse
    apenas um tamanho de tela.
-   Considerar 4 GB de RAM como referência de desempenho.
-   A plataforma de construção começa com uma área delimitada e pode
    crescer/ser expandida.
-   Não usar paredes altas ou elementos que escondam a área de
    construção.

### 3.2 Câmera

**Modo inicial: isométrico.**

-   Ângulo fixo.
-   Botão para girar a câmera em passos de 90°.
-   Zoom por gesto de pinça.
-   Ação de recentralizar a construção.
-   A câmera não deve girar acidentalmente durante o arraste de uma
    peça.

**Futuro, fora do MVP:** modo de câmera livre, selecionável como
alternativa. A arquitetura deve evitar acoplar a lógica de construção ao
tipo de câmera.

### 3.3 Bandeja de peças

-   Bandeja vertical no lado esquerdo.
-   Área de construção ocupa a maior parte da tela.
-   A bandeja pode ser recolhida para ampliar a área de construção.
-   Categorias podem organizar as peças.
-   A bandeja apresenta estoque infinito: arrastar uma peça cria uma
    instância para posicionamento; a peça de origem permanece
    disponível.
-   O arraste começa na bandeja e termina na área de construção.
-   A proporção inicial sugerida para a bandeja é aproximadamente 20% da
    largura, ajustável após testes no dispositivo real. Não tratar esse
    valor como medida rígida.

### 3.4 Construção e posicionamento

-   Sistema modular com uma unidade básica comum.
-   Grade invisível para organizar posições.
-   Encaixe magnético (snapping) ao aproximar uma peça de posições
    válidas.
-   A grade e o encaixe magnético trabalham juntos: a grade define
    posições possíveis; o snapping ajuda a encontrar essas posições.
-   Peças não podem interpenetrar nem ocupar o mesmo espaço físico.
-   Peças devem se apoiar na plataforma ou em outras peças; não devem
    ficar flutuando sem suporte.
-   O posicionamento inválido deve ser recusado de maneira clara e
    previsível. Não forçar a peça a atravessar outra.
-   Rotação em incrementos de 90°, não rotação livre.
-   A lógica de construção deve ser independente da interface, da câmera
    e da aparência visual.

**Importante:** a regra exata para suporte de peças, pontes, balanços e
estabilidade precisa ser validada com um protótipo. Não implemente
simulação física complexa sem necessidade. Proponha a regra mais simples
que preserve a sensação de brinquedo de montar e apresente-a para
aprovação se houver escolhas de produto envolvidas.

### 3.5 Interação

-   Método inicial: tocar e arrastar.
-   A peça acompanha o dedo durante o arraste.
-   O sistema procura posições válidas e mostra feedback visual de
    encaixe.
-   Ao soltar, posicionar somente se o local for válido.
-   Se não houver posição válida, não criar uma peça sobreposta;
    retornar a peça à origem ou cancelar a operação de forma
    compreensível.
-   A arquitetura de interação deve permitir adicionar outro método no
    futuro (por exemplo, selecionar e depois tocar no destino), sem
    reescrever o sistema de construção.

### 3.6 Ferramentas do MVP

-   Arrastar e soltar.
-   Girar 90°.
-   Apagar peça selecionada.
-   Desfazer e refazer.
-   Salvamento automático.

**Não incluir duplicação no MVP.** A criança cria outra peça
arrastando-a novamente da bandeja.

### 3.7 Catálogo inicial de peças

A proposta inicial é de oito tipos. As dimensões abaixo são referências
modulares preliminares; o Argon deve conferir coerência geométrica e
apresentar dúvidas antes de implementar formas ambíguas.

  Peça                  Dimensão modular preliminar
  ------------------- -----------------------------
  Cubo                                    1 × 1 × 1
  Bloco comprido                          2 × 1 × 1
  Placa quadrada                       2 × 2 × 0,25
  Prancha                              3 × 1 × 0,25
  Rampa                                   2 × 1 × 1
  Prisma triangular                       2 × 1 × 1
  Cilindro                                1 × 1 × 1
  Meio cilindro                           2 × 1 × 1

Observações: - As dimensões da rampa, do prisma triangular e do meio
cilindro precisam de uma definição geométrica precisa antes de serem
tratadas como especificação final. - Peças não cúbicas precisam de
regras adequadas de colisão e encaixe; não assumir que todas podem usar
uma caixa de colisão cúbica sem avaliar o resultado. - Para reduzir
risco, o primeiro protótipo funcional pode começar com cubo, bloco
comprido, placa e rampa. Acrescentar as demais formas após validar o
posicionamento.

### 3.8 Aparência visual

A direção visual desejada é a de um brinquedo físico bem produzido:

-   Iluminação suave, com fonte principal e iluminação ambiente.
-   Sombras de contato e sensação de profundidade.
-   Pequenos chanfros ou bordas suavizadas nas peças.
-   Materiais foscos, cores agradáveis e sem excesso de textura.
-   Plataforma e fundo simples, sem competir com as construções.
-   Evitar aparência de cubos chapados ou protótipo técnico.

A primeira versão deve usar um único tema visual. A geometria das peças
deve ser separada de seus materiais e aparências para permitir temas
futuros (por exemplo, madeira, plástico colorido ou temas especiais) sem
reimplementar o sistema de construção.

**Desempenho:** priorizar técnicas econômicas para dispositivos móveis.
Não depender de iluminação global dinâmica ou efeitos caros sem
demonstrar necessidade e desempenho no hardware-alvo. Avaliar o custo de
sombras, ambient occlusion, chanfros e materiais no tablet real.

### 3.9 Projetos e salvamento

-   Vários projetos independentes no mesmo tablet.
-   Salvamento automático local.
-   Funcionamento offline.
-   Cada projeto recebe um nome automático (por exemplo, "Construção
    1").
-   O nome pode ser editado opcionalmente.
-   Deve ser possível criar, abrir e excluir projetos.
-   Não exigir cadastro ou login de alunos.
-   A galeria deve deixar claro qual construção será aberta ou excluída.
-   O formato salvo deve armazenar dados de construção (identificador da
    peça, posição, rotação e demais propriedades necessárias), não
    depender de salvar a cena 3D inteira como estado opaco.
-   Projetos devem continuar abrindo após fechar e reabrir o aplicativo.

A solução de armazenamento deve ser simples, robusta e local. O Argon
deve propor o formato e a estratégia de migração/versionamento do
arquivo de projeto antes de consolidar a implementação.

------------------------------------------------------------------------

## 4. Arquitetura técnica proposta

### 4.1 Tecnologia

-   Godot 4.x.
-   GDScript.
-   Renderizador Mobile.
-   Exportação Android.
-   Confirmar a versão do Godot disponível no ambiente antes de criar ou
    migrar o projeto. A versão 4.7.2 foi utilizada em trabalho anterior,
    mas o Argon deve verificar a instalação real e não presumir que está
    disponível.

### 4.2 Separação de responsabilidades

A arquitetura deve manter, no mínimo, as seguintes responsabilidades
separadas. Os nomes são conceituais; o Argon pode propor uma estrutura
de arquivos melhor, desde que preserve a separação.

  -----------------------------------------------------------------------
  Sistema                             Responsabilidade
  ----------------------------------- -----------------------------------
  `ConstructionManager`               Estado da construção,
                                      adicionar/remover peças e validar
                                      operações

  `PieceCatalog`                      Definições das peças, dimensões,
                                      geometria e metadados

  `PlacementSystem`                   Grade, snapping, colisão/interseção
                                      e posições válidas

  `InteractionController`             Entrada touch, seleção, arraste e
                                      rotação solicitada

  `CameraController`                  Câmera isométrica, zoom, rotação em
                                      90° e recentralização

  `PlatformController`                Área de construção e sua expansão

  `ConstructionUI`                    Bandeja, ferramentas, galeria e
                                      feedback

  `SaveManager`                       Criar, carregar, salvar e excluir
                                      projetos locais

  `Theme/Visuals`                     Materiais, iluminação e aparência,
                                      sem conter regras de construção
  -----------------------------------------------------------------------

### 4.3 Princípios de implementação

-   Preferir dados de peça declarativos (dimensões, tipo, pivô, regras
    de encaixe e referência visual).
-   Separar dados persistidos da representação visual 3D.
-   Não espalhar regras de encaixe em scripts de interface.
-   Não acoplar o posicionamento à câmera isométrica.
-   Usar colisões/validações determinísticas para impedir
    interpenetração.
-   Evitar física dinâmica contínua se uma solução determinística de
    posicionamento for suficiente.
-   Evitar criar um nó ou recurso pesado desnecessário para cada detalhe
    visual.
-   Medir desempenho no dispositivo-alvo; não inferir desempenho apenas
    pela execução no PC.

------------------------------------------------------------------------

## 5. Plano de desenvolvimento em fases

O Argon deve executar uma fase por vez, entregar evidências e aguardar
validação do usuário quando necessário.

### Fase 0 --- Inspeção e plano técnico

1.  Inspecionar o ambiente, a versão do Godot e a estrutura do projeto.
2.  Verificar configuração de exportação Android e disponibilidade de
    dispositivo de teste.
3.  Propor estrutura de pastas e cenas.
4.  Identificar riscos técnicos para snapping, colisões, câmera e touch.
5.  Apresentar um plano curto de implementação, sem ainda construir o
    aplicativo completo.

**Entrega:** relatório sucinto com ambiente encontrado, estrutura
proposta, riscos e dúvidas que exigem decisão.

### Fase 1 --- Protótipo visual e câmera

1.  Criar uma cena de construção com plataforma simples.
2.  Implementar câmera isométrica.
3.  Implementar rotação em passos de 90°, zoom e recentralização.
4.  Criar poucas peças provisórias com materiais simples, mas com boa
    leitura de volume.
5.  Validar enquadramento e proporções em orientação paisagem.

**Entrega:** protótipo executável para avaliação visual e de navegação.

### Fase 2 --- Construção e posicionamento

1.  Implementar unidade modular e grade invisível.
2.  Implementar criação de peça a partir da bandeja.
3.  Implementar arraste touch.
4.  Implementar snapping.
5.  Impedir interpenetração e posicionamento inválido.
6.  Implementar rotação em passos de 90°.
7.  Implementar feedback visual para posição válida/inválida.

**Entrega:** construir uma pequena estrutura no tablet usando as peças
iniciais. Testar especialmente arraste, precisão touch, encaixe e
colisões.

### Fase 3 --- Catálogo e ferramentas

1.  Completar as oito formas aprovadas, após resolver as geometrias
    pendentes.
2.  Implementar apagar.
3.  Implementar desfazer/refazer.
4.  Implementar bandeja lateral recolhível e categorias.
5.  Ajustar feedback e alvos touch para crianças.

**Entrega:** experiência básica de montagem completa, sem persistência
final.

### Fase 4 --- Projetos e persistência

1.  Implementar galeria.
2.  Criar projeto com nome automático.
3.  Permitir renomear e excluir.
4.  Salvar automaticamente.
5.  Carregar projetos existentes.
6.  Validar recuperação após fechar e reabrir o aplicativo.

**Entrega:** vários projetos locais independentes e recuperáveis.

### Fase 5 --- Acabamento e desempenho

1.  Refinar materiais, iluminação, sombras e chanfros.
2.  Ajustar layout para tablet de 10 polegadas.
3.  Verificar responsividade em telas menores quando possível.
4.  Medir desempenho no tablet real.
5.  Reduzir custos de renderização quando necessário.
6.  Verificar estabilidade em sessões prolongadas.

**Entrega:** versão candidata para testes com crianças.

------------------------------------------------------------------------

## 6. Critérios de aceitação do MVP

O MVP só deve ser considerado funcional quando:

-   [ ] Abre em orientação paisagem.
-   [ ] Exibe uma plataforma de construção e câmera isométrica.
-   [ ] A câmera gira em passos de 90°.
-   [ ] Zoom e recentralização funcionam.
-   [ ] A criança consegue arrastar uma peça da bandeja para a
    plataforma.
-   [ ] A peça original permanece na bandeja (estoque infinito).
-   [ ] As peças se alinham por grade e snapping.
-   [ ] Nenhuma peça atravessa ou ocupa o espaço de outra.
-   [ ] Posicionamentos inválidos são recusados de forma compreensível.
-   [ ] A rotação das peças ocorre em passos de 90°.
-   [ ] É possível apagar, desfazer e refazer.
-   [ ] É possível criar e manter vários projetos.
-   [ ] O nome automático pode ser alterado.
-   [ ] O salvamento é automático e local.
-   [ ] Projetos persistem após fechar e reabrir o app.
-   [ ] A experiência é testada no tablet Android de referência.
-   [ ] O desempenho é aceitável no dispositivo real, não apenas no PC.

------------------------------------------------------------------------

## 7. Questões em aberto --- não presumir respostas

O Argon deve identificar estas questões durante a investigação e propor
opções curtas quando elas precisarem ser resolvidas:

1.  **Geometria exata das peças especiais:** definir perfil, pivô,
    orientação e pontos de contato da rampa, prisma triangular e meio
    cilindro.
2.  **Regra de suporte:** validar como o sistema determina se uma peça
    está apoiada, especialmente em pontes e balanços. Evitar física
    complexa sem necessidade.
3.  **Expansão da plataforma:** definir limites e comportamento de
    expansão sem tornar a área de construção confusa.
4.  **Desfazer/refazer:** definir quais operações formam uma ação
    reversível (por exemplo, arrastar uma peça deve ser uma única ação).
5.  **Comportamento de arraste inválido:** confirmar se a peça retorna à
    bandeja ou à posição anterior, conforme sua origem.
6.  **Galeria:** propor uma apresentação simples e adequada ao uso
    compartilhado por vários alunos.

Não bloqueie o primeiro protótipo por questões que ainda não sejam
necessárias. Registre as pendências e resolva-as na fase correspondente.

------------------------------------------------------------------------

## 8. Primeira tarefa do Argon

Comece exclusivamente pela **Fase 0 --- Inspeção e plano técnico**.

Não implemente funcionalidades ainda.

Inspecione o ambiente e apresente, de forma sucinta:

1.  Versão do Godot encontrada.
2.  Estado/configuração do projeto existente.
3.  Viabilidade de exportação Android.
4.  Estrutura de pastas e cenas recomendada.
5.  Principais riscos técnicos, especialmente snapping, colisão e
    interação touch.
6.  Dúvidas que precisam de decisão antes da Fase 1.

**Aguarde aprovação antes de iniciar a Fase 1.**
