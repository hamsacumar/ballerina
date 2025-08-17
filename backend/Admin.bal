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
        allowCredentials: false,
        allowHeaders: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    }
}

service /admin on new http:Listener(9093) {

    function init() returns error? {
        log:printInfo("Admin service initialized successfully");
    }

    // Utility function to get user's link count
    private function getUserLinkCount(json userId) returns int|error {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        
        int count = check linkCollection->countDocuments({userId: userId});
        return count;
    }

    // Utility function to get user's category count
    private function getUserCategoryCount(json userId) returns int|error {
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        
        int count = check categoryCollection->countDocuments({userId: userId});
        return count;
    }

    // Utility function to get user's last updated timestamp from links collection
    private function getUserLastUpdated(json userId) returns string|error {
        mongodb:Collection linkCollection = check myDb->getCollection("links");

        // Find the most recent update from links
        mongodb:FindOptions linkOptions = {
            sort: {"updatedAt": -1},
            'limit: 1
        };

        stream<record {|string updatedAt; anydata...;|}, error?> linkStream =
            check linkCollection->find({userId: userId}, linkOptions);

        string lastUpdated = "";
        error? linkError = linkStream.forEach(function(record {|string updatedAt; anydata...;|} link) {
            lastUpdated = link.updatedAt;
        });

        if linkError is error {
            log:printError("Error fetching latest update: " + linkError.toString());
            return "";
        }
        
        return lastUpdated;
    }

    // Health check endpoint
    resource function get health() returns json {
        return {"status": "healthy", "service": "admin", "timestamp": time:utcNow()};
    }

    // Get all users data for table format
    resource function get users() returns UserTableResponse[]|http:InternalServerError {

        do {
            mongodb:Collection userCollection = check myDb->getCollection("users");
            
            // Get all users
            stream<record {|anydata...;|}, error?> userStream = check userCollection->find({});
            
            UserTableResponse[] userDetails = [];
            
            check userStream.forEach(function(record {|anydata...;|} user) {
                do {
                    json userId = <json>user["_id"];
                    string name = <string>(user["username"] ?: "");
                    string email = <string>(user["email"] ?: "");
                    string createdAt = <string>(user["createdAt"] ?: "");

                    // Get counts for this user
                    int linkCount = check self.getUserLinkCount(userId);
                    int categoryCount = check self.getUserCategoryCount(userId);
                    string lastUpdated = check self.getUserLastUpdated(userId);

                    UserTableResponse userDetail = {
                        _id: userId,
                        name: name,
                        email: email,
                        createdAt: createdAt,
                        linkCount: linkCount,
                        categoryCount: categoryCount,
                        lastUpdated: lastUpdated
                    };

                    userDetails.push(userDetail);
                } on fail var e {
                    log:printError("Error processing user: " + e.toString());
                }
            });

            return userDetails;
        } on fail var e {
            log:printError("Failed to retrieve users: " + e.toString());
            return <http:InternalServerError>{
                body: {"message": "Failed to retrieve users: " + e.toString()}
            };
        }
    }

    // Get specific user details by user ID
    resource function get users/[string userId]() returns UserTableResponse|http:NotFound|http:InternalServerError {

        do {
            mongodb:Collection userCollection = check myDb->getCollection("users");
            
            // Create ObjectId for the query
            map<json> userObjectId = {"$oid": userId};
            
            stream<record {|anydata...;|}, error?> userStream = 
                check userCollection->find({_id: userObjectId});
            
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
            json userIdJson = <json>user["_id"];
            string name = <string>(user["username"] ?: "");
            string email = <string>(user["email"] ?: "");
            string createdAt = <string>(user["createdAt"] ?: "");

            // Get counts for this user
            int linkCount = check self.getUserLinkCount(userIdJson);
            int categoryCount = check self.getUserCategoryCount(userIdJson);
            string lastUpdated = check self.getUserLastUpdated(userIdJson);

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

    // Get user's links by user ID
    resource function get users/[string userId]/links() returns json[]|http:InternalServerError {

        do {
            mongodb:Collection linkCollection = check myDb->getCollection("links");
            map<json> userObjectId = {"$oid": userId};
            
            stream<record {|anydata...;|}, error?> linkStream = 
                check linkCollection->find({userId: userObjectId});
            
            json[] links = [];
            check linkStream.forEach(function(record {|anydata...;|} link) {
                links.push(<json>link.cloneReadOnly());
            });

            return links;
        } on fail var e {
            log:printError("Failed to retrieve user links: " + e.toString());
            return <http:InternalServerError>{
                body: {"message": "Failed to retrieve user links: " + e.toString()}
            };
        }
    }

    // Get user's categories by user ID
    resource function get users/[string userId]/categories() returns json[]|http:InternalServerError {

        do {
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");
            map<json> userObjectId = {"$oid": userId};
            
            stream<record {|anydata...;|}, error?> categoryStream = 
                check categoryCollection->find({userId: userObjectId});
            
            json[] categories = [];
            check categoryStream.forEach(function(record {|anydata...;|} category) {
                categories.push(<json>category.cloneReadOnly());
            });

            return categories;
        } on fail var e {
            log:printError("Failed to retrieve user categories: " + e.toString());
            return <http:InternalServerError>{
                body: {"message": "Failed to retrieve user categories: " + e.toString()}
            };
        }
    }

    // Get admin dashboard statistics
    resource function get stats() returns AdminStats|http:InternalServerError {

        do {
            mongodb:Collection userCollection = check myDb->getCollection("users");
            mongodb:Collection linkCollection = check myDb->getCollection("links");
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");

            // Get total counts
            int totalUsers = check userCollection->countDocuments({});
            int totalLinks = check linkCollection->countDocuments({});
            int totalCategories = check categoryCollection->countDocuments({});
            
            // Get verified/unverified user counts
            int verifiedUsers = check userCollection->countDocuments({isEmailVerified: true});
            int unverifiedUsers = check userCollection->countDocuments({isEmailVerified: false});

            AdminStats stats = {
                totalUsers: totalUsers,
                totalLinks: totalLinks,
                totalCategories: totalCategories,
                verifiedUsers: verifiedUsers,
                unverifiedUsers: unverifiedUsers,
                generatedAt: time:utcToString(time:utcNow())
            };

            return stats;
        } on fail var e {
            log:printError("Failed to retrieve admin statistics: " + e.toString());
            return <http:InternalServerError>{
                body: {"message": "Failed to retrieve statistics: " + e.toString()}
            };
        }
    }

    // Delete user and all associated data
    resource function delete users/[string userId]() returns json|http:NotFound|http:InternalServerError {

        do {
            mongodb:Collection userCollection = check myDb->getCollection("users");
            mongodb:Collection linkCollection = check myDb->getCollection("links");
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");
            
            map<json> userObjectId = {"$oid": userId};

            // Check if user exists
            stream<record {|anydata...;|}, error?> userStream = 
                check userCollection->find({_id: userObjectId});
            
            record {|anydata...;|}[] users = [];
            check userStream.forEach(function(record {|anydata...;|} user) {
                users.push(user);
            });

            if users.length() == 0 {
                return <http:NotFound>{
                    body: {"message": "User not found"}
                };
            }

            // Delete user's links
            mongodb:DeleteResult linkDeleteResult = check linkCollection->deleteMany({userId: userObjectId});
            
            // Delete user's categories
            mongodb:DeleteResult categoryDeleteResult = check categoryCollection->deleteMany({userId: userObjectId});
            
            // Delete the user
            mongodb:DeleteResult userDeleteResult = check userCollection->deleteOne({_id: userObjectId});

            return {
                "message": "User and all associated data deleted successfully",
                "deletedUser": userDeleteResult.deletedCount,
                "deletedLinks": linkDeleteResult.deletedCount,
                "deletedCategories": categoryDeleteResult.deletedCount
            };
        } on fail var e {
            log:printError("Failed to delete user: " + e.toString());
            return <http:InternalServerError>{
                body: {"message": "Failed to delete user: " + e.toString()}
            };
        }
    }

    // Update user role (promote/demote admin)
    resource function put users/[string userId]/role(@http:Payload json roleData) 
            returns json|http:BadRequest|http:NotFound|http:InternalServerError {

        do {
            map<json> requestData = <map<json>>roleData;
            string? newRole = <string?>requestData["role"];
            
            if newRole is () || (newRole != "admin" && newRole != "user") {
                return <http:BadRequest>{
                    body: {"message": "Invalid role. Must be 'admin' or 'user'"}
                };
            }

            mongodb:Collection userCollection = check myDb->getCollection("users");
            map<json> userObjectId = {"$oid": userId};

            // Check if user exists
            stream<record {|anydata...;|}, error?> userStream = 
                check userCollection->find({_id: userObjectId});
            
            record {|anydata...;|}[] users = [];
            check userStream.forEach(function(record {|anydata...;|} user) {
                users.push(user);
            });

            if users.length() == 0 {
                return <http:NotFound>{
                    body: {"message": "User not found"}
                };
            }

            // Update user role
            mongodb:Update updateOperation = {
                set: {
                    role: newRole
                }
            };

            mongodb:UpdateResult updateResult = check userCollection->updateOne({_id: userObjectId}, updateOperation);

            if updateResult.modifiedCount == 0 {
                return <http:InternalServerError>{
                    body: {"message": "Failed to update user role"}
                };
            }

            return {
                "message": string `User role updated to ${newRole} successfully`,
                "userId": userId,
                "newRole": newRole
            };
        } on fail var e {
            log:printError("Failed to update user role: " + e.toString());
            return <http:InternalServerError>{
                body: {"message": "Failed to update user role: " + e.toString()}
            };
        }
    }
}