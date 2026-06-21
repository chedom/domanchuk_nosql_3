// 5.1. PageRank на графі фільмів
// Крок 1: матеріалізуємо ребра фільм-фільм через спільних користувачів
MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND id(m1) < id(m2)
WITH m1, m2, count(u) AS weight
WHERE size([(m1)<-[:RATED]-() | 1]) > 20
  AND size([(m2)<-[:RATED]-() | 1]) > 20
WITH m1, m2, weight
ORDER BY weight DESC
LIMIT 50000
MERGE (m1)-[co:CO_RATED]-(m2)
SET co.weight = weight;

// Крок 2: створюємо проєкцію на основі матеріалізованих ребер
CALL gds.graph.project(
  'movieGraph',
  'Movie',
  { CO_RATED: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: Запускаємо алгоритм PageRank на створеній проєкції
CALL gds.pageRank.stream('movieGraph', {
  relationshipWeightProperty: 'weight'
})
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS m, score
RETURN m.title AS MovieTitle, m.year AS Year, score AS PageRankScore
ORDER BY PageRankScore DESC
LIMIT 20;

// Крок 4: видаляємо проєкцію та тимчасові ребра
CALL gds.graph.drop('movieGraph');
MATCH ()-[co:CO_RATED]-() DELETE co;

// 5.2 Виявлення спільнот (Louvain)

// Крок 1: матеріалізуємо ребра користувач-користувач через спільні фільми
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND id(u1) < id(u2)
WITH u1, u2, count(m) AS weight
WITH u1, u2, weight
ORDER BY weight DESC
LIMIT 50000
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight;

// Крок 2: створюємо проєкцію
CALL gds.graph.project(
  'userSimilarity',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;
// Крок 3.1: запускаємо алгоритм Louvain для виявлення спільнот
CALL gds.louvain.write('userSimilarity', {
  relationshipWeightProperty: 'weight',
  writeProperty: 'communityId'
})
YIELD communityCount, modularity, modularities;

// Крок 3.2. Визначаємо розміри отриманих кластерів і виводимо 10 найбільших з них
MATCH (u:User)
WHERE u.communityId IS NOT NULL
WITH u.communityId AS community, count(u) AS clusterSize
RETURN community AS ClusterID, clusterSize AS TotalUsers
ORDER BY clusterSize DESC
LIMIT 10;

// Крок 4: аналізуємо одну з найбільших спільнот (наприклад, ClusterID = 0) за віком та статтю
// Збираємо топ-10 найбільших спільнот
MATCH (u:User)
WITH u.communityId AS community, count(u) AS clusterSize
ORDER BY clusterSize DESC
LIMIT 10
// Для цих спільнот знаходимо жанри фільмів, які користувачі оцінили на 4 або 5
MATCH (u:User {communityId: community})-[r:RATED]->(m:Movie)-[:IN_GENRE]->(g:Genre)
WHERE r.rating >= 4
WITH community, clusterSize, g.name AS genreName, count(r) AS genreVotes
ORDER BY community, genreVotes DESC
// Групуємо та виділяємо топ-3 жанри для кожного кластера
WITH community, clusterSize, collect({genre: genreName, votes: genreVotes})[..3] AS topGenres
RETURN community AS ClusterID, 
       clusterSize AS UsersCount, 
       [g IN topGenres | g.genre + " (" + g.votes + ")"] AS Top3Genres;

// Крок 5: видаляємо проєкцію та тимчасові ребра
CALL gds.graph.drop('userSimilarity');
MATCH ()-[sim:SIMILAR]-() DELETE sim;
