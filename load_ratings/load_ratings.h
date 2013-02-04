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

#ifndef load_ratings_load_ratings_h
#define load_ratings_load_ratings_h

typedef struct store_sqlite3_t store_sqlite3_t;
store_sqlite3_t* store_sqlite3_init(const char *db_name);
void store_sqlite3_movie(store_sqlite3_t *ctx, int votes, double score,
                         const char *name);
void store_sqlite3_close(store_sqlite3_t *ctx);

#endif
