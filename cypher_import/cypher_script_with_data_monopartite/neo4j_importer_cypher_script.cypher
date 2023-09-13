:param {
  // Define the file path root and the individual file names required for loading.
  // https://neo4j.com/docs/operations-manual/current/configuration/file-locations/
  file_path_root: 'file:///', // Change this to the folder your script can access the files at.
  file_0: 'accounts.csv',
  file_1: 'txs.csv'
};

// CONSTRAINT creation
// -------------------
//
// Create node uniqueness constraints, ensuring no duplicates for the given node label and ID property exist in the database. This also ensures no duplicates are introduced in future.
//
// NOTE: The following constraint creation syntax is generated based on the current connected database version 5.12-aura.
CREATE CONSTRAINT `imp_uniq_Account_accountNumber` IF NOT EXISTS
FOR (n: `Account`)
REQUIRE (n.`accountNumber`) IS UNIQUE;

:param {
  idsToSkip: []
};

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
  MERGE (n: `Account` { `accountNumber`: row.`a_id` })
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
  MATCH (source: `Account` { `accountNumber`: row.`from_id` })
  MATCH (target: `Account` { `accountNumber`: row.`to_id` })
  MERGE (source)-[r: `TRANSACTION`]->(target)
  SET r.`tx_id` = row.`tx_id`
  SET r.`amount` = toFloat(trim(row.`amount`))
  // Your script contains the datetime datatype. Our app attempts to convert dates to ISO 8601 date format before passing them to the Cypher function.
  // This conversion cannot be done in a Cypher script load. Please ensure that your CSV file columns are in ISO 8601 date format to ensure equivalent loads.
  // SET r.`date` = datetime(row.`date`)
} IN TRANSACTIONS OF 10000 ROWS;
