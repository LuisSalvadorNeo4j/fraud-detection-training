:param  file_path_root => 'https://raw.githubusercontent.com/halftermeyer/fraud-detection-training/main/data/data_csv/big/';
:param file_0 => 'accounts.csv';
:param file_1 => 'txs.csv';

// CONSTRAINT creation
// -------------------
//
// Create node uniqueness constraints, ensuring no duplicates for the given node label and ID property exist in the database. This also ensures no duplicates are introduced in future.
//
// NOTE: The following constraint creation syntax is generated based on the current connected database version 5.12-aura.
CREATE CONSTRAINT `imp_uniq_Account_a_id` IF NOT EXISTS
FOR (n: `Account`)
REQUIRE (n.`a_id`) IS UNIQUE;

:param idsToSkip => [];

// NODE load
// ---------
//
// Load nodes in batches, one node label at a time. Nodes will be created using a MERGE statement to ensure a node with the same label and ID property remains unique. Pre-existing nodes found by a MERGE statement will have their other properties set to the latest values encountered in a load file.
//
// NOTE: Any nodes with IDs in the 'idsToSkip' list parameter will not be loaded.
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_0) AS row
WITH row
WHERE NOT row.`a_id` IN $idsToSkip AND NOT row.`a_id` IS NULL
CALL {
  WITH row
  MERGE (n: `Account` { `a_id`: row.`a_id` })
  SET n.`name` = row.`name`
  SET n.`email` = row.`email`
} IN TRANSACTIONS OF 10000 ROWS;


// RELATIONSHIP load
// -----------------
//
// Load relationships in batches, one relationship type at a time. Relationships are created using a MERGE statement, meaning only one relationship of a given type will ever be created between a pair of nodes.
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_1) AS row
WITH row 
CALL {
  WITH row
  MATCH (source: `Account` { `a_id`: row.`from_id` })
  MATCH (target: `Account` { `a_id`: row.`to_id` })
  CREATE (source)-[r: `TRANSACTION`]->(target)
  SET r.`tx_id` = row.`tx_id`
  SET r.`amount` = toFloat(trim(row.`amount`))
  SET r.`date` = datetime(row.`date`)
  // Your script contains the datetime datatype. Our app attempts to convert dates to ISO 8601 date format before passing them to the Cypher function.
  // This conversion cannot be done in a Cypher script load. Please ensure that your CSV file columns are in ISO 8601 date format to ensure equivalent loads.
  // SET r.`date` = datetime(row.`date`)
} IN TRANSACTIONS OF 10000 ROWS;
