# Atividade 02 — Integração com a API TMDB (PDM2)

Aplicativo Flutter desenvolvido para a disciplina de **Programação para Dispositivos Móveis 2 (PDM2)**, evoluindo a base do projeto com a integração de operações autenticadas e consulta de dados na API **The Movie Database (TMDB)**.

---

## 📋 Funcionalidades Implementadas

Foram implementados e integrados à interface gráfica os seguintes endpoints da API v3 do TMDB:

1. **Próximos Lançamentos (`GET /movie/upcoming`)**
   - Consulta a lista de filmes com lançamento previsto.
   - Exibe pôster, título e data de lançamento na tela inicial (`UpcomingMoviesView`).

2. **Gerenciamento de Favoritos (`POST /account/{account_id}/favorite`)**
   - Permite ao usuário autenticado adicionar ou remover um filme da sua lista de favoritos na tela de detalhes (`MovieDetailView`).
   - Atualiza o estado visual do botão e exibe feedback via `SnackBar`.

3. **Avaliação de Filmes (`POST /movie/{movie_id}/rating`)**
   - Permite atribuir notas de **0,5 a 10,0** (com incrementos de **0,5**) por meio de um componente `Slider`.
   - Envia a avaliação vinculada à sessão do usuário e exibe confirmação visual.

4. **Remoção de Avaliação (`DELETE /movie/{movie_id}/rating`)**
   - Permite excluir uma avaliação previamente registrada para o filme selecionado, exibindo feedback imediato na interface.

---

## 🏗️ Arquitetura e Organização do Projeto

O projeto mantém a separação de responsabilidades entre interface, modelos de dados e comunicação HTTP:

```text
lib/
├── main.dart                     # Ponto de entrada da aplicação
├── models/
│   └── movie_model.dart          # Modelo tipado para conversão do JSON da API TMDB
├── services/
│   └── tmdb_service.dart         # Camada de comunicação REST utilizando o pacote Dio
└── views/
    ├── login_view.dart           # Fluxo de autenticação e geração de session_id
    ├── upcoming_movies_view.dart # Tela de listagem de próximos lançamentos (FutureBuilder)
    └── movie_detail_view.dart    # Tela de detalhes com ações autenticadas (favoritar e avaliar)
