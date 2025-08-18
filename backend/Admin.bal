import ballerina/http;
import ballerina/time;
import ballerinax/mongodb;
import ballerina/log;

// Type definitions for Admin module
public type AdminUser record {|
    json _id?;
    string username;
    string email;
    string role;
    string createdAt?;
    boolean isEmailVerified?;
    int linkCount?;
    int categoryCount?;
    string lastUpdated?;
|};

public type UserLink record {|
    json _id?;
    string name;
    string url;
    string icon?;
    json categoryId;
    json userId;
    string createdAt?;
    string updatedAt?;
|};

public type UserCategory record {|
    json _id?;
    string name;
    json userId;
    string[] links?;
    string createdAt?;
    string updatedAt?;
|};

public type AdminStats record {|
    int totalUsers;
    int totalLinks;
    int totalCategories;
    int verifiedUsers;
    int unverifiedUsers;
    string generatedAt;
|};

// Table format response type
public type UserTableResponse record {|
    json _id;
    string name;
    string email;
    string createdAt;
    int linkCount;
    int categoryCount;
    string lastUpdated;
|};

@http:ServiceConfig {
    cors: {
        allowOrigins: ["http://localhost:4200"],
        allowCredentials: true,
        allowHeaders: ["Authorization", "Content-Type"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        exposeHeaders: ["*"],
        maxAge: 3600
    }
}
service /admin on new http:Listener(9093) {

    function init() returns error? {
        log:printInfo("Admin service initialized successfully");
    }

    // FIXED: Utility function to get user's link count using username as fallback
    private function getUserLinkCount(json userId, string username) returns int|error {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        
        // Debug: Log the userId format
        log:printInfo("Fetching link count for userId: " + userId.toString() + ", username: " + username);
        
        int count = 0;
        
        // Try to use the userId ObjectId
        if userId != () {
            // Try different ObjectId formats
            
            // First try: Direct match
            do {
                count = check linkCollection->countDocuments({userId: userId});
                log:printInfo("Direct ObjectId match - Link count: " + count.toString());
                if count > 0 {
                    return count;
                }
            } on fail var e {
                log:printDebug("Direct ObjectId match failed: " + e.toString());
            }
            
            // Second try: String format
            do {
                string userIdStr = userId.toString();
                if userIdStr.startsWith("\"") && userIdStr.endsWith("\"") {
                    userIdStr = userIdStr.substring(1, userIdStr.length() - 1);
                }
                count = check linkCollection->countDocuments({userId: userIdStr});
                log:printInfo("String format match - Link count: " + count.toString());
                if count > 0 {
                    return count;
                }
            } on fail var e {
                log:printDebug("String format match failed: " + e.toString());
            }
            
            // Third try: Extract ObjectId string
            do {
                if userId is map<json> {
                    json? oidValue = userId["$oid"];
                    if oidValue is string {
                        count = check linkCollection->countDocuments({userId: oidValue});
                        log:printInfo("Extracted OID match - Link count: " + count.toString());
                        if count > 0 {
                            return count;
                        }
                    }
                }
            } on fail var e {
                log:printDebug("Extracted OID match failed: " + e.toString());
            }
        }
        
        // Fallback: Try using username if your links collection stores usernames
        do {
            count = check linkCollection->countDocuments({username: username});
            log:printInfo("Username fallback match - Link count: " + count.toString());
            if count > 0 {
                return count;
            }
        } on fail var e {
            log:printDebug("Username fallback match failed: " + e.toString());
        }
        
        log:printWarn("No links found for user: " + username);
        return 0;
    }

    // FIXED: Utility function to get user's category count using username as fallback
    private function getUserCategoryCount(json userId, string username) returns int|error {
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        
        // Debug: Log the userId format
        log:printInfo("Fetching category count for userId: " + userId.toString() + ", username: " + username);
        
        int count = 0;
        
        // Try to use the userId ObjectId
        if userId != () {
            // Try different ObjectId formats
            
            // First try: Direct match
            do {
                count = check categoryCollection->countDocuments({userId: userId});
                log:printInfo("Direct ObjectId match - Category count: " + count.toString());
                if count > 0 {
                    return count;
                }
            } on fail var e {
                log:printDebug("Direct ObjectId match failed: " + e.toString());
            }
            
            // Second try: String format
            do {
                string userIdStr = userId.toString();
                if userIdStr.startsWith("\"") && userIdStr.endsWith("\"") {
                    userIdStr = userIdStr.substring(1, userIdStr.length() - 1);
                }
                count = check categoryCollection->countDocuments({userId: userIdStr});
                log:printInfo("String format match - Category count: " + count.toString());
                if count > 0 {
                    return count;
                }
            } on fail var e {
                log:printDebug("String format match failed: " + e.toString());
            }
            
            // Third try: Extract ObjectId string
            do {
                if userId is map<json> {
                    json? oidValue = userId["$oid"];
                    if oidValue is string {
                        count = check categoryCollection->countDocuments({userId: oidValue});
                        log:printInfo("Extracted OID match - Category count: " + count.toString());
                        if count > 0 {
                            return count;
                        }
                    }
                }
            } on fail var e {
                log:printDebug("Extracted OID match failed: " + e.toString());
            }
        }
        
        // Fallback: Try using username
        do {
            count = check categoryCollection->countDocuments({username: username});
            log:printInfo("Username fallback match - Category count: " + count.toString());
            if count > 0 {
                return count;
            }
        } on fail var e {
            log:printDebug("Username fallback match failed: " + e.toString());
        }
        
        log:printWarn("No categories found for user: " + username);
        return 0;
    }

    // FIXED: Utility function to get user's last updated timestamp using username as fallback
    private function getUserLastUpdated(json userId, string username) returns string|error {
        mongodb:Collection linkCollection = check myDb->getCollection("links");

        // Debug: Log the userId format
        log:printInfo("Fetching last updated for userId: " + userId.toString() + ", username: " + username);

        // Try updatedAt first, then createdAt as fallback
        mongodb:FindOptions linkOptions = {
            sort: {"updatedAt": -1},
            'limit: 1
        };

        string lastUpdated = "";
        
        // Try to use the userId ObjectId
        if userId != () {
            // Try different ObjectId formats to find the most recent link
            
            // First try: Direct match
            do {
                stream<record {|string updatedAt; anydata...;|}, error?> linkStream =
                    check linkCollection->find({userId: userId}, linkOptions);
                
                error? linkError = linkStream.forEach(function(record {|string updatedAt; anydata...;|} link) {
                    lastUpdated = link.updatedAt;
                });
                
                if linkError is error {
                    log:printDebug("Direct match stream error: " + linkError.toString());
                } else if lastUpdated != "" {
                    log:printInfo("Direct ObjectId match - Last updated: " + lastUpdated);
                    return lastUpdated;
                }
            } on fail var e {
                log:printDebug("Direct ObjectId match failed: " + e.toString());
            }
            
            // Second try: String format
            do {
                string userIdStr = userId.toString();
                if userIdStr.startsWith("\"") && userIdStr.endsWith("\"") {
                    userIdStr = userIdStr.substring(1, userIdStr.length() - 1);
                }
                
                stream<record {|string updatedAt; anydata...;|}, error?> linkStream =
                    check linkCollection->find({userId: userIdStr}, linkOptions);
                
                error? linkError = linkStream.forEach(function(record {|string updatedAt; anydata...;|} link) {
                    lastUpdated = link.updatedAt;
                });
                
                if linkError is error {
                    log:printDebug("String match stream error: " + linkError.toString());
                } else if lastUpdated != "" {
                    log:printInfo("String format match - Last updated: " + lastUpdated);
                    return lastUpdated;
                }
            } on fail var e {
                log:printDebug("String format match failed: " + e.toString());
            }
            
            // Third try: Extract ObjectId string
            do {
                if userId is map<json> {
                    json? oidValue = userId["$oid"];
                    if oidValue is string {
                        stream<record {|string updatedAt; anydata...;|}, error?> linkStream =
                            check linkCollection->find({userId: oidValue}, linkOptions);
                        
                        error? linkError = linkStream.forEach(function(record {|string updatedAt; anydata...;|} link) {
                            lastUpdated = link.updatedAt;
                        });
                        
                        if linkError is error {
                            log:printDebug("Extracted OID match stream error: " + linkError.toString());
                        } else if lastUpdated != "" {
                            log:printInfo("Extracted OID match - Last updated: " + lastUpdated);
                            return lastUpdated;
                        }
                    }
                }
            } on fail var e {
                log:printDebug("Extracted OID match failed: " + e.toString());
            }
        }
        
        // Fallback: Try using username
        do {
            stream<record {|string updatedAt; anydata...;|}, error?> linkStream =
                check linkCollection->find({username: username}, linkOptions);
            
            error? linkError = linkStream.forEach(function(record {|string updatedAt; anydata...;|} link) {
                lastUpdated = link.updatedAt;
            });
            
            if linkError is error {
                log:printDebug("Username fallback stream error: " + linkError.toString());
            } else if lastUpdated != "" {
                log:printInfo("Username fallback match - Last updated: " + lastUpdated);
                return lastUpdated;
            }
        } on fail var e {
            log:printDebug("Username fallback match failed: " + e.toString());
        }
        
        log:printWarn("No last updated found for user: " + username);
        return "";
    }

    // Health check endpoint
    resource function get health() returns json {
        return {"status": "healthy", "service": "admin", "timestamp": time:utcNow()};
    }

    // Debug endpoint to check database contents
    resource function get debug/counts() returns json|http:InternalServerError {
        do {
            mongodb:Collection linkCollection = check myDb->getCollection("links");
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");
            mongodb:Collection userCollection = check myDb->getCollection("users");

            int totalLinks = check linkCollection->countDocuments({});
            int totalCategories = check categoryCollection->countDocuments({});
            int totalUsers = check userCollection->countDocuments({});

            return {
                "totalUsers": totalUsers,
                "totalLinks": totalLinks,
                "totalCategories": totalCategories,
                "message": "Database collection counts"
            };
        } on fail var e {
            return <http:InternalServerError>{
                body: {"message": "Failed to get counts: " + e.toString()}
            };
        }
    }

    // FIXED: Get all users data with explicit _id field inclusion and username fallback
    resource function get users() returns UserTableResponse[]|http:InternalServerError {

        do {
            mongodb:Collection userCollection = check myDb->getCollection("users");
            
            // Get all users with explicit _id field inclusion
            stream<record {|json _id; anydata...;|}, error?> userStream = check userCollection->find({});
            
            UserTableResponse[] userDetails = [];
            
            check userStream.forEach(function(record {|json _id; anydata...;|} user) {
                do {
                    // DEBUG: Log the entire user document structure
                    log:printInfo("Raw user document: " + user.toString());
                    
                    // Extract user data - now _id should be available
                    json userIdRaw = user._id;
                    string name = <string>(user["username"] ?: "");
                    string email = <string>(user["email"] ?: "");
                    string createdAt = <string>(user["createdAt"] ?: "");

                    // Debug: Log the _id format
                    log:printInfo("User " + name + " has _id: " + userIdRaw.toString());

                    // Use the actual _id from database
                    json userIdJson = userIdRaw;
                    
                    log:printInfo("Processing user: " + name + " with ID: " + userIdJson.toString());

                    // Get counts for this user with error handling (using username as fallback)
                    int linkCount = 0;
                    int categoryCount = 0;
                    string lastUpdated = "";

                    // Try to get link count
                    do {
                        linkCount = check self.getUserLinkCount(userIdRaw, name);
                    } on fail var e {
                        log:printError("Failed to get link count for user " + name + ": " + e.toString());
                        linkCount = 0;
                    }

                    // Try to get category count
                    do {
                        categoryCount = check self.getUserCategoryCount(userIdRaw, name);
                    } on fail var e {
                        log:printError("Failed to get category count for user " + name + ": " + e.toString());
                        categoryCount = 0;
                    }

                    // Try to get last updated
                    do {
                        lastUpdated = check self.getUserLastUpdated(userIdRaw, name);
                    } on fail var e {
                        log:printError("Failed to get last updated for user " + name + ": " + e.toString());
                        lastUpdated = "";
                    }

                    UserTableResponse userDetail = {
                        _id: userIdJson,
                        name: name,
                        email: email,
                        createdAt: createdAt,
                        linkCount: linkCount,
                        categoryCount: categoryCount,
                        lastUpdated: lastUpdated
                    };

                    userDetails.push(userDetail);
                    log:printInfo("Successfully processed user: " + name + 
                                 " (Links: " + linkCount.toString() + 
                                 ", Categories: " + categoryCount.toString() + 
                                 ", LastUpdated: " + lastUpdated + ")");
                } on fail var e {
                    log:printError("Error processing user: " + e.toString());
                }
            });

            log:printInfo("Successfully fetched " + userDetails.length().toString() + " users");
            return userDetails;
        } on fail var e {
            log:printError("Failed to retrieve users: " + e.toString());
            return <http:InternalServerError>{
                body: {"message": "Failed to retrieve users: " + e.toString()}
            };
        }
    }

    // Get specific user details by user ID (modified to handle username search)
    resource function get users/[string userIdentifier]() returns UserTableResponse|http:NotFound|http:InternalServerError {

        do {
            mongodb:Collection userCollection = check myDb->getCollection("users");
            
            // Try to find by ObjectId first, then by username
            stream<record {|anydata...;|}, error?> userStream;
            
            // First try: Search by ObjectId
            do {
                map<json> userObjectId = {"$oid": userIdentifier};
                userStream = check userCollection->find({_id: userObjectId});
            } on fail {
                // Second try: Search by username
                userStream = check userCollection->find({username: userIdentifier});
            }
            
            record {|anydata...;|}[] users = [];
            check userStream.forEach(function(record {|anydata...;|} user) {
                users.push(user);
            });

            if users.length() == 0 {
                return <http:NotFound>{
                    body: {"message": "User not found"}
                };
            }

            record {|anydata...;|} user = users[0];
            json? userIdRaw = <json?>user["_id"];
            string name = <string>(user["username"] ?: "");
            string email = <string>(user["email"] ?: "");
            string createdAt = <string>(user["createdAt"] ?: "");

            // Create a dummy _id if missing (using username as identifier)
            json userIdJson = userIdRaw ?: name;

            // Get counts for this user
            int linkCount = check self.getUserLinkCount(userIdRaw, name);
            int categoryCount = check self.getUserCategoryCount(userIdRaw, name);
            string lastUpdated = check self.getUserLastUpdated(userIdRaw, name);

            UserTableResponse userDetail = {
                _id: userIdJson,
                name: name,
                email: email,
                createdAt: createdAt,
                linkCount: linkCount,
                categoryCount: categoryCount,
                lastUpdated: lastUpdated
            };

            return userDetail;
        } on fail var e {
            log:printError("Failed to retrieve user details: " + e.toString());
            return <http:InternalServerError>{
                body: {"message": "Failed to retrieve user details: " + e.toString()}
            };
        }
    }
}