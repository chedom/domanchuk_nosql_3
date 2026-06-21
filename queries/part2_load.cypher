// 1. Створюємо індекси до завантаження ребер — це прискорить пошук вузлів при створенні зв’язків:
CREATE CONSTRAINT unique_userId IF NOT EXISTS FOR (u:User) REQUIRE u.userId IS UNIQUE;
CREATE CONSTRAINT unique_movieId IF NOT EXISTS FOR (m:Movie) REQUIRE m.movieId IS UNIQUE;
CREATE CONSTRAINT unique_genreName IF NOT EXISTS FOR (g:Genre) REQUIRE g.name IS UNIQUE;
// 2. Завантажуємо користувачів з CSV файлу та створюємо вузли User
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {userId: toInteger(row.userId)})
SET u.gender = row.gender,
    u.age = toInteger(row.age),
    u.occupation = toInteger(row.occupation);
// 3. Завантажуємо фільми з CSV файлу та створюємо вузли Movie
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MERGE (m:Movie {movieId: toInteger(row.movieId)})
SET 
  // Витягуємо рік за допомогою регулярного виразу (шукаємо 4 цифри в дужках в кінці рядка)
  m.year = toInteger(apoc.text.regexGroups(row.title, '\((\d{4})\)$')[0][1]),
  // Очищаємо назву фільму від року та зайвих пробілів в кінці
  m.title = trim(replace(row.title, apoc.text.regexGroups(row.title, '\((\d{4})\)$')[0][0], ""))
WITH m, row
UNWIND split(row.genres, "|") AS genreName
MERGE (g:Genre {name: genreName})
MERGE (m)-[:IN_GENRE]->(g);
// 4. Завантажуємо рейтинги з CSV файлу та створюємо ребра RATED між користувачами та фільмами
CALL apoc.periodic.iterate(
  // перший запит — генерує потік елементів
  "LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row RETURN row",
  
  // другий запит — застосовується до кожного елемента
  "MATCH (u:User {userId: toInteger(row.userId)})
   MATCH (m:Movie {movieId: toInteger(row.movieId)})
   MERGE (u)-[r:RATED]->(m)
   SET r.rating = toInteger(row.rating),
       r.timestamp = toInteger(row.timestamp)",
       
  // Параметри конфігурації
  {batchSize: 50000,   parallel: false}
)
YIELD batches, total, errorMessages
RETURN batches, total, errorMessages;
// 5. Перевірка результатів
MATCH (u:User) RETURN count(u) AS users;
MATCH (m:Movie) RETURN count(m) AS movies;
MATCH ()-[r:RATED]->() RETURN count(r) AS ratings;
