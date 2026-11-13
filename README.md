# Máquina de Vender Salgados — VHDL

**Universidade Estadual do Sudoeste da Bahia (UESB)**  
**Disciplina:** Tópicos de Informática Aplicada (TIA/ADM)  
**Professor:** Marco A. D. Ramos  
**Discentes:** Eduardo Ribeiro Fontes e Pedro Cândido  
**Data:** 25 de setembro de 2026

---

## 1. Sobre o projeto

Este projeto consiste no desenvolvimento de uma máquina automática de venda de salgados, utilizando a linguagem de descrição de hardware **VHDL**.

O sistema simula o funcionamento de uma máquina comercial, permitindo que o usuário selecione um produto, insira moedas, acompanhe o saldo acumulado e receba o produto adquirido. Também contempla situações como falta de estoque, inserção de moedas inválidas e desistência da compra, com devolução dos valores depositados.

O funcionamento é controlado por uma **Máquina de Estados Finitos (FSM)**, composta por quatro estados principais: `AGUARDANDO`, `AVISO`, `RECEBENDO` e `LIBERANDO`.

## 2. Funcionalidades

O sistema apresenta as seguintes funcionalidades:

- Seleção de cinco produtos diferentes.
- Consulta da disponibilidade dos produtos em estoque.
- Aceitação de moedas de R$ 0,25, R$ 0,50 e R$ 1,00.
- Identificação de moedas inválidas.
- Acumulação do saldo inserido pelo usuário.
- Exibição do saldo em displays de sete segmentos.
- Liberação automática do produto após atingir o preço necessário.
- Cálculo e liberação de troco.
- Possibilidade de desistência da compra.
- Devolução integral das moedas em caso de desistência.

## 3. Produtos e preços

Os produtos são selecionados por meio de um vetor de três bits (`sel_produto`).

| Código | Produto | Preço |
|:---:|---|---:|
| 000 | Batata frita grande | R$ 2,50 |
| 001 | Batata frita média | R$ 1,50 |
| 010 | Batata frita pequena | R$ 0,75 |
| 011 | Tortilha grande | R$ 3,50 |
| Outros | Tortilha pequena | R$ 2,00 |

Os preços são armazenados internamente em centavos, utilizando números inteiros para evitar operações com valores decimais.

## 4. Arquitetura do sistema

A arquitetura é composta por uma entidade chamada `bombom01` e uma arquitetura interna denominada `arc_bombons`.

A entidade define as entradas e saídas responsáveis pela comunicação com os componentes externos da máquina.

### 4.1. Entradas

| Entrada | Descrição |
|---|---|
| `clk` | Sinal de clock responsável pela sincronização do sistema. |
| `reset` | Reinicializa a máquina. |
| `moeda_valor` | Informa o valor da moeda inserida, em centavos. |
| `moeda_inserida` | Indica a chegada de uma moeda. |
| `sel_produto` | Código do produto selecionado. |
| `confirma_selecao` | Confirma a escolha do produto. |
| `desiste` | Solicita o cancelamento da compra. |
| `estoque` | Informa a disponibilidade dos cinco produtos. |

### 4.2. Saídas

| Saída | Descrição |
|---|---|
| `moedas_aceitas` | Indica as três moedas aceitas pelo sistema. |
| `aviso_sem_estoque` | Sinaliza a indisponibilidade do produto. |
| `moeda_invalida` | Indica a inserção de uma moeda não reconhecida. |
| `libera_salgado` | Autoriza a liberação do produto. |
| `libera_troco` | Indica que existe troco a devolver. |
| `libera_todas_as_moedas` | Solicita a devolução integral em caso de desistência. |
| `display_reais` | Apresenta a parte inteira do saldo. |
| `display_decimo` | Apresenta o primeiro decimal do saldo. |
| `preco` | Informa o preço do produto selecionado. |
| `saldo` | Informa o valor acumulado. |
| `troco` | Informa o valor a ser devolvido. |

## 5. Máquina de Estados Finitos (FSM)

O controle operacional utiliza quatro estados, responsáveis por organizar as etapas da compra.

### 5.1. AGUARDANDO

É o estado inicial da máquina.

O sistema aguarda que o usuário selecione um produto e pressione o botão de confirmação.

Após a confirmação, verifica a disponibilidade do produto no estoque:

- Se houver estoque, a máquina passa para `RECEBENDO`.
- Se não houver estoque, passa para `AVISO`.

### 5.2. AVISO

Este estado é acionado quando o produto selecionado não está disponível.

O sinal `aviso_sem_estoque` é ativado para informar o usuário.

Após uma nova confirmação, o sistema retorna ao estado `AGUARDANDO`, permitindo uma nova escolha.

### 5.3. RECEBENDO

Neste estado, a máquina começa a receber as moedas do usuário.

São aceitos os seguintes valores:

- R$ 0,25 (25 centavos);
- R$ 0,50 (50 centavos);
- R$ 1,00 (100 centavos).

Quando uma moeda válida é inserida, seu valor é acrescentado ao saldo acumulado.

Caso seja identificada uma moeda inválida, o sinal `moeda_invalida` é ativado e o valor não é contabilizado.

O sistema verifica continuamente se o saldo acumulado atingiu ou ultrapassou o preço do produto.

Quando o pagamento é suficiente, ocorre a transição para o estado `LIBERANDO`.

O usuário também pode desistir da compra a qualquer momento durante esse estado. Nesse caso, o sistema solicita a devolução integral do saldo e retorna ao estado inicial.

### 5.4. LIBERANDO

Este estado é responsável pela conclusão da compra.

O sinal `libera_salgado` é ativado para autorizar a entrega do produto.

Em seguida, o sistema verifica se o valor depositado ultrapassou o preço:

- Se o pagamento for exato, não haverá troco.
- Se o pagamento for superior ao preço, o sistema calcula a diferença e ativa `libera_troco`.

Após concluir a operação, o saldo é zerado e a máquina retorna ao estado `AGUARDANDO`.

## 6. Funcionamento dos displays

O projeto utiliza dois displays de sete segmentos para apresentar o saldo acumulado.

A conversão dos valores é realizada por meio da função `seg7`, responsável por transformar cada algarismo decimal em sua representação binária correspondente para os segmentos do display.

Exemplo:

| Saldo acumulado | Display de reais | Display decimal |
|---|---:|---:|
| R$ 0,25 | 0 | 2 |
| R$ 1,50 | 1 | 5 |
| R$ 2,75 | 2 | 7 |
| R$ 3,00 | 3 | 0 |

O primeiro display apresenta a parte inteira do saldo, enquanto o segundo apresenta a dezena dos centavos.

## 7. Exemplo de operação

Considere uma situação em que o usuário deseja comprar uma batata frita grande, cujo preço é R$ 2,50.

1. O usuário seleciona o produto pelo código `000`.
2. Pressiona o botão de confirmação.
3. A máquina verifica se existe estoque disponível.
4. O sistema entra no estado `RECEBENDO`.
5. O usuário insere uma moeda de R$ 1,00.
6. O saldo passa a ser R$ 1,00.
7. O usuário insere outra moeda de R$ 1,00.
8. O saldo passa a ser R$ 2,00.
9. O usuário insere uma moeda de R$ 1,00.
10. O saldo chega a R$ 3,00.
11. A máquina entra no estado `LIBERANDO`.
12. O produto é liberado e o sistema calcula R$ 0,50 de troco.
13. O saldo é zerado e a máquina retorna ao estado `AGUARDANDO`.

## 8. Estruturas e recursos utilizados em VHDL

O desenvolvimento utiliza os seguintes recursos da linguagem:

- **Entity:** define a interface de entrada e saída do sistema.
- **Architecture:** descreve o funcionamento interno da máquina.
- **Signals:** armazenam informações utilizadas entre os processos.
- **Variables:** auxiliam nos cálculos internos durante a execução dos processos.
- **Process:** organiza a lógica combinacional e sequencial.
- **Case:** permite selecionar operações de acordo com os estados e códigos dos produtos.
- **Function:** realiza a conversão dos algarismos para os displays de sete segmentos.
- **FSM:** controla as etapas e transições de funcionamento da máquina.

## 9. Considerações finais

O projeto demonstra a aplicação dos conceitos de lógica digital e descrição de hardware por meio da linguagem VHDL.

A utilização de uma máquina de estados finitos permite organizar o funcionamento da máquina de venda, separando as operações de seleção, verificação de estoque, recebimento de moedas e liberação dos produtos.

Dessa forma, o sistema apresenta uma simulação funcional dos principais mecanismos de uma máquina automática de venda de alimentos, contemplando tanto o fluxo normal de compra quanto situações excepcionais, como moedas inválidas, falta de estoque e desistência do usuário.

---

**Desenvolvido como atividade acadêmica da disciplina Tópicos de Informática Aplicada — UESB.**
