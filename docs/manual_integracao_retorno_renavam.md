# Manual de Integração - Retorno RENAVAM

**Versão:** 0.3 (Rascunho de Homologação)  
**Data:** 12 de junho de 2026  
**Status:** Sob Revisão  

---

## 1. Introdução e Objetivo

Este documento tem como objetivo orientar as equipes técnicas dos integradores parceiros na configuração de seus ambientes para o recebimento e consumo das informações de retorno do RENAVAM. 

Aqui são detalhados a estrutura do payload de dados enviado pelo nosso serviço e os canais de entrega disponíveis (RabbitMQ, Webhook/API e Kafka), de forma a garantir a correta recepção e tratamento das mensagens nos sistemas de destino.

---

## 2. Esquema de Dados (JSON Schema)

Os dados de passagem integrados ao retorno cadastral são fornecidos em formato JSON. A tabela a seguir descreve cada campo presente na mensagem de entrega:

### Tabela de Campos

| Campo | Tipo | Descrição | Exemplo | Observação |
| :--- | :--- | :--- | :--- | :--- |
| `placa` | `string` | Placa do veículo que gerou a passagem. | `ABC1D23` | |
| `data_passagem` | `string` | Data e hora da passagem do veículo, no padrão ISO 8601 UTC. | `2026-06-12T19:45:00Z` | Formato: `YYYY-MM-DDTHH:MM:SSZ` |
| `orgao` | `string` | Órgão de trânsito ou segurança responsável pelo ponto de leitura. | `ORGAO-A` | |
| `empresa` | `string` | Identificação da empresa integradora parceira. | `Integrador A` | |
| `equipamento` | `string` | Identificador único da câmera ou equipamento que registrou a passagem. | `Equipamento B` | |
| `status` | `string` | Status resultante do processamento ou consulta cadastral do veículo. | `OK` | Indica o sucesso da consulta (`OK`) ou motivo de inconsistência (ex: `passagem sem imagem fornecida`). |
| `veiculo` | `object` | Objeto contendo os dados cadastrais do veículo retornados da base. | Ver abaixo | **Sempre Presente**: O objeto é sempre enviado na raiz. Se `status` for diferente de `"OK"`, ele retorna vazio (`{}`). |

### Estrutura do Objeto `veiculo`

O objeto `veiculo` está **sempre presente** no JSON raiz para garantir a estabilidade do contrato de dados. Seus campos internos só serão preenchidos se o campo `status` for igual a `"OK"`. Caso contrário, será entregue um objeto vazio `{}`.

| Campo | Tipo | Descrição | Exemplo |
| :--- | :--- | :--- | :--- |
| `tipo_veiculo` | `string` | Categoria/tipo do veículo (ex: automóvel, motocicleta, caminhão). | `AUTOMOVEL` |
| `marca_modelo` | `string` | Marca e modelo do veículo conforme registro. | `VW/GOL 1.0` |
| `cor` | `string` | Cor predominante do veículo. | `PRATA` |
| `ano_fabricacao` | `integer`/`string` | Ano de fabricação do veículo. | `2020` |
| `ano_modelo` | `integer`/`string` | Ano do modelo do veículo. | `2021` |
| `municipio_emplacamento`| `string` | Município onde o veículo está registrado/emplacado. | `SAO PAULO` |
| `uf_emplacamento` | `string` | Unidade Federativa (estado) do emplacamento. | `SP` |
| `restricao_roubo_furto` | `boolean` | Indica se há registro ativo de roubo ou furto para o veículo. | `false` |

### Exemplo de Payload (Consulta com Sucesso - status `"OK"`)

```json
{
  "placa": "ABC1D23",
  "data_passagem": "2026-06-12T22:45:30Z",
  "orgao": "ORGAO-A",
  "empresa": "Integrador A",
  "equipamento": "Equipamento B",
  "status": "OK",
  "veiculo": {
    "tipo_veiculo": "AUTOMOVEL",
    "marca_modelo": "FORD/KA SE 1.0",
    "cor": "BRANCO",
    "ano_fabricacao": 2019,
    "ano_modelo": 2020,
    "municipio_emplacamento": "CIDADE A",
    "uf_emplacamento": "SP",
    "restricao_roubo_furto": false
  }
}
```

### Exemplo de Payload (Inconsistência/Erro - status diferente de `"OK"`)

```json
{
  "placa": "XYZ9K99",
  "data_passagem": "2026-06-12T22:46:12Z",
  "orgao": "ORGAO-A",
  "empresa": "Integrador A",
  "equipamento": "Equipamento B",
  "status": "passagem sem imagem fornecida",
  "veiculo": {}
}
```

---

## 3. Canais e Opções de Integração (Envio)

O envio dos eventos aos integradores ocorre por meio de canais de integração ativos ou reativos, de acordo com o modelo de conexão homologado para o parceiro:

### A. Fila de Mensagens - RabbitMQ (AMQP 0.9)
* **Perfil de Uso**: Parceiros configurados para recebimento via fila de mensageria (ex: `Integrador A` e `Integrador B`).
* **Protocolo**: AMQP 0.9 sobre conexão segura com TLS (`amqps`).
* **Modo de Envio**: Envio individual de mensagens persistentes diretamente em um Exchange com Routing Key configurada pelo cliente.
* **Formato do Payload**: JSON (UTF-8).

### B. Integração via API - HTTP POST (Webhook)
* **Perfil de Uso**: Integradores que optam pelo recebimento passivo de chamadas de API (ex: `Integrador C`).
* **Protocolo**: HTTPS POST.
* **Modo de Envio**: **Envio em Lote (Batching)**. O serviço agrupa mensagens geradas em uma janela curta e realiza chamadas HTTP contendo um array de mensagens JSON (`json_array`).
* **Parâmetros do Lote**:
  - Máximo de registros por chamada: 100 mensagens.
  - Janela de tempo de agrupamento: 5 segundos.
* **Autenticação**: Envio de token de segurança personalizado via cabeçalho HTTP `token`.
* **Políticas de Resiliência e Retentativa (Retry)**:
  - **Tentativas Automáticas**: Em caso de falha de conexão, timeout ou indisponibilidade temporária do servidor de destino (erros na faixa 5xx), o serviço realiza até **3 retentativas** automáticas.
  - **Intervalo de Reenvio**: O intervalo inicial é de **1 segundo** (*retry period*), adotando uma política de recuo exponencial (*backoff*) limitado ao máximo de **30 segundos** (*max backoff*).
* **Política de Descarte (Drop)**:
  - Para evitar o travamento de filas de entrega por falhas permanentes de integração do lado do destinatário, o lote de mensagens é **descartado de forma imediata** (sem novas tentativas) caso o servidor do integrador retorne os seguintes códigos de erro HTTP: **400, 401, 403, 404, 405 e 422**.

### C. Streaming de Dados - Apache Kafka
* **Perfil de Uso**: Parceiros integrados diretamente por tópicos de streaming (ex: `Integrador D` / `ORGAO-B`).
* **Protocolo**: Kafka com suporte a autenticação SASL.
* **Modo de Envio**: Publicação em lote (máximo de 100 registros ou 5 segundos) no tópico cadastrado.
* **Chave da Mensagem (Key)**: A chave de partição da mensagem no Kafka é a própria **placa** do veículo. Isso garante a ordenação cronológica das passagens de um mesmo veículo dentro da partição de destino.

---

## 4. Acordo de Nível de Serviço (SLA) e Requisitos de Dados

Os parceiros integradores contam com os seguintes acordos de nível de serviço (SLA) estabelecidos no fluxo de dados de entrega:

### A. SLA de Recência e Latência de Entrega
* **Atraso Máximo da Mensagem**: O atraso máximo tolerado para entrega da mensagem de passagem no sistema de destino é de **15 minutos**. 
* **Regra de Validação**: A diferença de tempo entre o momento de geração da passagem do veículo (`data_passagem`) e o momento de recepção/envio ao sistema do integrador não deve ser superior a 15 minutos.

### B. SLA de Requisitos de Conteúdo (Imagens)
* **Existência de Imagem associada**: Toda mensagem integrada deve permitir a associação com a foto do registro de passagem.
* **Mecanismos de Obtenção**: O dado deve conter a imagem codificada em **Base64** ou, alternativamente, disponibilizar um **identificador único de imagem** válido para que o integrador possa realizar a requisição e download da mídia via API pública disponibilizada para esse fim.
