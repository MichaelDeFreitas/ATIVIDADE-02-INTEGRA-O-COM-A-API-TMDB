# Atividade 02 — Integração com a API TMDB (PDM2)

Aplicativo Flutter de consulta aos próximos lançamentos e de operações autenticadas de favoritos e avaliações usando a API REST do The Movie Database (TMDB).

## Funcionalidades e endpoints

| Funcionalidade | Método e endpoint | Integração na interface |
|---|---|---|
| Próximos lançamentos | `GET /movie/upcoming` | Lista título, pôster e data; permite atualizar com gesto de arrastar |
| Consultar favoritos | `GET /account/{account_id}/favorite/movies` | Aba Favoritos com pôster, título e data; sincroniza os corações |
| Consultar avaliações pessoais | `GET /account/{account_id}/rated/movies` | Aba Minhas avaliações, exibindo a nota individual enviada pelo usuário |
| Adicionar/remover favorito | `POST /account/{account_id}/favorite` | Botão de coração com feedback e atualização visual |
| Avaliar filme | `POST /movie/{movie_id}/rating` | Seletor de 0,5 a 10,0, em passos de 0,5 |
| Remover avaliação | `DELETE /movie/{movie_id}/rating` | Botão de lixeira na aba Minhas avaliações, com confirmação |

## Requisitos

- Flutter SDK instalado e configurado.
- Uma conta no [TMDB](https://www.themoviedb.org/).
- Um **API Read Access Token (v4)** criado nas configurações da conta TMDB: [Configurações de API](https://www.themoviedb.org/settings/api).

## Instalação e execução

1. Clone o repositório e abra a pasta do projeto.
2. Instale as dependências:

   ```bash
   flutter pub get
   ```

3. Execute informando o Read Access Token sem gravá-lo nos arquivos do projeto:

   ```bash
   flutter run --dart-define=TMDB_ACCESS_TOKEN=COLE_SEU_READ_ACCESS_TOKEN
   ```

   No PowerShell, o comando é o mesmo. Substitua o texto pelo seu token pessoal. Não publique o token em commits, prints ou no README.

> **Segurança:** `--dart-define` evita deixar a credencial escrita no código-fonte, mas valores incorporados em um aplicativo cliente podem ser extraídos do binário. Para um aplicativo de produção, use um backend para intermediar chamadas que dependam de segredo. O token v4 não deve ser tratado como segredo inviolável em um app distribuído.

## Como testar

1. Abra o aplicativo com conexão à internet. A tela inicial consulta `GET /movie/upcoming` e apresenta os filmes retornados.
2. Toque em **Conectar TMDB**. O app cria um request token, abre a página oficial de autorização no navegador e aguarda a confirmação do usuário.
3. Entre na conta TMDB no navegador, autorize o aplicativo e volte ao Flutter. Toque em **Já autorizei**. O app cria a sessão, consulta o identificador da conta e armazena a sessão no armazenamento seguro do dispositivo.
4. Use o coração de um filme para adicionar/remover dos favoritos. O resultado é enviado por `POST /account/{account_id}/favorite` e a interface muda somente após sucesso da API.
5. Abra a aba **Favoritos** para consultar a lista da sua conta. Use o coração para adicionar ou remover filmes; a lista é atualizada após a confirmação da API.
6. Na aba **Lançamentos**, use o ícone de avaliação para escolher uma nota de 0,5 a 10,0 (incrementos de 0,5) e enviar por `POST /movie/{movie_id}/rating`.
7. Abra **Minhas avaliações** para consultar os filmes avaliados e a sua nota individual retornada pelo TMDB. A média geral do TMDB aparece separadamente, quando disponível.
8. Use o botão de lixeira em **Minhas avaliações** para confirmar a remoção por `DELETE /movie/{movie_id}/rating`. A avaliação sai da lista após sucesso da API.
9. Puxe cada lista para baixo para atualizá-la. Use o ícone de sair para remover a sessão armazenada neste dispositivo.

## Organização do código

```text
lib/
  main.dart                 # Interface com abas, estado e fluxo de autenticação
  models/
    movie_model.dart        # Modelo Dart tipado e conversão JSON
  services/
    tmdb_service.dart       # Comunicação HTTP com Dio e endpoints TMDB
```

- **Comunicação:** Dio centralizado em `TmdbService`.
- **Modelo:** `Movie.fromJson` converte os dados JSON em objeto Dart tipado; `userRating` representa a avaliação pessoal retornada pelo endpoint de filmes avaliados, sem confundi-la com `voteAverage` (média pública).
- **Estado:** `StatefulWidget` e `setState` controlam carregamento, erro, operações em andamento e atualização da interface.
- **Sessão:** `flutter_secure_storage` guarda o identificador da sessão e da conta no dispositivo.
- **Autorização:** `url_launcher` abre a página oficial do TMDB para aprovação do request token.
- **Feedback:** indicadores de carregamento, mensagens de sucesso/erro e confirmação antes de excluir avaliação.

## Observações

- Operações de conta exigem sessão TMDB válida. Sem autenticação, a listagem pública de próximos lançamentos continua disponível.
- A API TMDB pode retornar filmes diferentes conforme região, idioma, data e disponibilidade.
- O projeto precisa ser executado localmente com Flutter e um token válido para validar chamadas reais. A ausência de credenciais impede testar as operações autenticadas neste ambiente.
- Consulte os termos de uso e atribuição da [TMDB API](https://developer.themoviedb.org/docs/getting-started).
