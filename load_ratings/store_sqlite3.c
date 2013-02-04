/*
 * Copyright 2013 Lieven Govaerts
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <stdio.h>
#include <stdlib.h>
#include <sqlite3.h>

#include <string.h>

#include "load_ratings.h"

/*
 CREATE TABLE movies(id integer primary key, votes integer, score double, name varchar(1024));
 CREATE TABLE ngrams(id integer primary key, ngram char(4), movie integer);
 */
/*
 fuzzy search:
 'select count(*) as match, movies.name from ngrams,movies where ngram in ("Ant", "nth", "tho", "hon", "ons", "nse", "sen") and movies.id=ngrams.movie  group by movie order by match desc limit 10;'
 */
struct store_sqlite3_t
{
    sqlite3 *db;
    sqlite3_stmt *insert_movie_stmt;
    sqlite3_stmt *insert_ngram_stmt;
};

static const char* insert_movie_query = "INSERT INTO movies(votes, score, name) "
                                        "VALUES (?, ?, ?)";
static const char* insert_ngram_query = "INSERT INTO ngrams(ngram, movie) "
                                        "VALUES (?, ?)";

#define SQL_ERR(x)\
    { int err; err = (x); if (err) { fprintf(stderr, "sqlite error: %d\n", err); } }
store_sqlite3_t* store_sqlite3_init(const char *db_name)
{
    sqlite3 *db;
    int rc;
    store_sqlite3_t *ctx;

    rc = sqlite3_open(db_name, &db);
    if( rc ){
        fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
        sqlite3_close(db);
        return 0l;
    }

    ctx = (store_sqlite3_t *)malloc(sizeof(store_sqlite3_t));
    ctx->db = db;
    /* Prepare statement */
    sqlite3_prepare_v2(db, insert_movie_query, strlen(insert_movie_query),
                       &ctx->insert_movie_stmt, NULL);
    sqlite3_prepare_v2(db, insert_ngram_query, strlen(insert_ngram_query),
                       &ctx->insert_ngram_stmt, NULL);

    return ctx;
}

void store_sqlite3_movie(store_sqlite3_t *ctx, int votes, double score,
                         const char *name)
{
    sqlite3 *db = ctx->db;

    sqlite3_bind_int(ctx->insert_movie_stmt, 1, votes);
    sqlite3_bind_double(ctx->insert_movie_stmt, 2, score);
    sqlite3_bind_text(ctx->insert_movie_stmt, 3, name, strlen(name), SQLITE_TRANSIENT);

    sqlite3_step(ctx->insert_movie_stmt);
    sqlite3_reset(ctx->insert_movie_stmt);

    /* store ngrams */
    sqlite3_int64 rowid = sqlite3_last_insert_rowid(db);

    char *p;
    for (p = name; p < name + strlen(name)-2; p++) {
        char ngram[4];

        strncpy(ngram, p, 3); *(ngram+3) = 0;
        
        SQL_ERR(sqlite3_bind_text(ctx->insert_ngram_stmt, 1, ngram, strlen(ngram), SQLITE_TRANSIENT));
        SQL_ERR(sqlite3_bind_int(ctx->insert_ngram_stmt, 2, rowid));

        sqlite3_step(ctx->insert_ngram_stmt);
        SQL_ERR(sqlite3_reset(ctx->insert_ngram_stmt));
    }
}

void store_sqlite3_close(store_sqlite3_t *ctx)
{
    sqlite3 *db = ctx->db;

    sqlite3_finalize(ctx->insert_movie_stmt);
    sqlite3_finalize(ctx->insert_ngram_stmt);
    sqlite3_close(ctx->db);
    ctx = 0l;
}
