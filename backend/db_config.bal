import ballerinax/mongodb;

// Configuration values from config.toml
configurable string connectionString = ?;

// MongoDB connection configuration
public final mongodb:Client mongoDb = check new ({
    connection: connectionString
});

// Get database instance
public isolated function getDatabase(string ballerina) returns mongodb:Database|error {
    return check mongoDb->getDatabase(ballerina);
}

public final mongodb:Database myDb;

function init() returns error? {
    myDb = check mongoDb->getDatabase("ballerina");
}