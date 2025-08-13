import ballerina/http;
import ballerina/jwt;
import ballerina/time;
import ballerinax/mongodb;

// Type definitions
public type Category record {|
    json _id?;
    string name;
    json userId; // Changed to json to handle ObjectId
    string[] links?;
    string createdAt?;
    string updatedAt?;
|};

public type Link record {|
    json _id?;
    string name;
    string url;
    string icon?;
    json categoryId; 
    json userId; 
    string createdAt?;
    string updatedAt?;
|};

public type CategoryRequest record {|
    string name;
|};

public type LinkRequest record {|
    string name;
    string url;
    string categoryId; 
|};

public type CategoryUpdate record {|
    string name;
|};

public type LinkUpdate record {|
    string? name?;
    string? url?;
    string? categoryId?;
|};

public type SearchResult record {|
    Link[] links;
    Category[] categories;
|};

public type IconUpdateRequest record {|
    string iconUrl;
|};

public type ErrorResponse record {|
    string message;
    int code?;
|};

public type JWTPayload record {|
    string username;
    string email;
    string role;
    string iss;
    string aud;
    int exp;
    int iat;
|};

@http:ServiceConfig {
    cors: {
        allowOrigins: ["http://localhost:4200"],
        allowCredentials: false,
        allowHeaders: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    }
}

service /api on new http:Listener(9094) {
    private final http:ListenerJwtAuthHandler jwtHandler;

    function init() returns error? {
        self.jwtHandler = new (jwtValidatorConfig);
    }

    // FIXED: Utility function to verify JWT token and get user ID
    private function verifyTokenAndGetUserId(string authHeader) returns map<json>|http:Unauthorized|http:Forbidden|error {
        jwt:Payload|http:Unauthorized authn = self.jwtHandler.authenticate(authHeader);
        if authn is http:Unauthorized {
            return authn;
        }

        http:Forbidden? authz = self.jwtHandler.authorize(<jwt:Payload>authn, ["admin", "user"]);
        if authz is http:Forbidden {
            return authz;
        }

        jwt:Payload payload = <jwt:Payload>authn;
        string? username = <string?>payload["username"];

        if username is () {
            return error("Invalid token: missing username");
        }

        // FIXED: Get user ID from users collection with proper error handling
        mongodb:Collection userCollection = check myDb->getCollection("users");

        // Use a more specific filter and handle the result properly
        stream<record {|json _id; anydata...;|}, error?> userStream =
            check userCollection->find({username: username}, projection = {"_id": 1});

        record {|json _id; anydata...;|}[] users = [];
        check userStream.forEach(function(record {|json _id; anydata...;|} user) {
            users.push(user);
        });

        if users.length() == 0 {
            return error("User not found");
        }

        // Return the ObjectId as a map
        json userId = users[0]._id;
        if userId is map<json> {
            return userId;
        } else {
            return error("Invalid user ID format");
        }
    }

    // Utility function to convert string ID to ObjectId format
    private function createObjectId(string id) returns map<json> {
        return {"$oid": id};
    }

    // Utility function to extract ObjectId string from json
    private function extractObjectId(json id) returns string? {
        if id is map<json> && id["$oid"] is string {
            return <string>id["$oid"];
        }
        return ();
    }

    // Utility function to extract domain from URL
    private function extractDomain(string inputUrl) returns string|error {
        string cleanUrl = inputUrl;
        if (cleanUrl.startsWith("http://")) {
            cleanUrl = cleanUrl.substring(7);
        } else if (cleanUrl.startsWith("https://")) {
            cleanUrl = cleanUrl.substring(8);
        }

        int? slashIndex = cleanUrl.indexOf("/");
        if (slashIndex is int && slashIndex > 0) {
            cleanUrl = cleanUrl.substring(0, slashIndex);
        }

        int? colonIndex = cleanUrl.indexOf(":");
        if (colonIndex is int && colonIndex > 0) {
            cleanUrl = cleanUrl.substring(0, colonIndex);
        }

        return cleanUrl;
    }

    // Utility function to generate favicon URL
    private function generateFaviconUrl(string websiteUrl) returns string {
        string|error domain = self.extractDomain(websiteUrl);
        if (domain is error) {
            return "https://www.google.com/s2/favicons?domain=default";
        }
        return string `https://www.google.com/s2/favicons?domain=${domain}`;
    }

    // Health check endpoint
    resource function get health() returns json {
        return {"status": "healthy", "service": "link-saver", "timestamp": time:utcNow()};
    }

    //Check the valid token
    resource function get debug/token(@http:Header string Authorization) returns json {
        do {
            jwt:Payload|http:Unauthorized authn = self.jwtHandler.authenticate(Authorization);
            if authn is http:Unauthorized {
                return {"error": "Authentication failed", "step": "authenticate"};
            }

            http:Forbidden? authz = self.jwtHandler.authorize(<jwt:Payload>authn, ["admin", "user"]);
            if authz is http:Forbidden {
                return {"error": "Authorization failed", "step": "authorize"};
            }

            return {"success": true, "message": "Token is valid", "step": "complete"};
        } on fail var e {
            return {"error": "Exception occurred", "details": e.toString()};
        }
    }

    // =============== CATEGORY CRUD OPERATIONS ===============

    // FIXED: Create a new category
    resource function post categories(@http:Header string Authorization, CategoryRequest categoryData)
            returns json|http:BadRequest|http:InternalServerError|http:Unauthorized|http:Forbidden {

        map<json>|http:Unauthorized|http:Forbidden|error userIdResult = self.verifyTokenAndGetUserId(Authorization);
        if userIdResult is http:Unauthorized || userIdResult is http:Forbidden {
            return userIdResult;
        }
        if userIdResult is error {
            return <http:InternalServerError>{body: {"message": "Authentication failed: " + userIdResult.toString()}};
        }

        map<json> userId = <map<json>>userIdResult;

        do {
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");

            if (categoryData.name.trim().length() == 0) {
                return <http:BadRequest>{body: {"message": "Category name cannot be empty"}};
            }

            // Check if category exists for this user
            stream<record {|anydata...;|}, error?> existingStream =
                check categoryCollection->find({name: categoryData.name, userId: userId});

            record {|anydata...;|}[] existing = [];
            check existingStream.forEach(function(record {|anydata...;|} cat) {
                existing.push(cat);
            });

            if (existing.length() > 0) {
                return <http:BadRequest>{body: {"message": "Category with this name already exists"}};
            }

            // FIXED: Create category with proper userId
            record {|
                string name;
                map<json> userId;
                string[] links;
                string createdAt;
                string updatedAt;
            |} newCategory = {
                name: categoryData.name.trim(),
                userId: userId, // This should now properly contain the ObjectId
                links: [],
                createdAt: time:utcToString(time:utcNow()),
                updatedAt: time:utcToString(time:utcNow())
            };

            check categoryCollection->insertOne(newCategory);

            return {"message": "Category created successfully", "category": newCategory};
        } on fail var e {
            return <http:InternalServerError>{body: {"message": "Database operation failed: " + e.toString()}};
        }
    }

    // FIXED: Get all categories for authenticated user
    resource function get categories(@http:Header string Authorization)
            returns json[]|http:InternalServerError|http:Unauthorized|http:Forbidden {

        map<json>|http:Unauthorized|http:Forbidden|error userIdResult = self.verifyTokenAndGetUserId(Authorization);
        if userIdResult is http:Unauthorized || userIdResult is http:Forbidden {
            return userIdResult;
        }
        if userIdResult is error {
            return <http:InternalServerError>{body: {"message": "Authentication failed: " + userIdResult.toString()}};
        }

        map<json> userId = <map<json>>userIdResult;

        do {
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");

            // FIXED: Proper query with userId ObjectId
            stream<record {|anydata...;|}, error?> categoryStream =
                check categoryCollection->find({userId: userId});

            json[] categories = [];
            check categoryStream.forEach(function(record {|anydata...;|} category) {
                categories.push(<json>category.cloneReadOnly());
            });

            return categories;
        } on fail var e {
            return <http:InternalServerError>{body: {"message": "Failed to retrieve categories: " + e.toString()}};
        }
    }

    // Update a category
    resource function put categories/[string categoryId](@http:Header string Authorization, CategoryUpdate updateData)
            returns json|http:BadRequest|http:NotFound|http:InternalServerError|http:Unauthorized|http:Forbidden {

        map<json>|http:Unauthorized|http:Forbidden|error userIdResult = self.verifyTokenAndGetUserId(Authorization);
        if userIdResult is http:Unauthorized || userIdResult is http:Forbidden {
            return userIdResult;
        }
        if userIdResult is error {
            return <http:InternalServerError>{body: {"message": "Authentication failed"}};
        }

        map<json> userId = <map<json>>userIdResult;

        do {
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");

            if (updateData.name.trim().length() == 0) {
                return <http:BadRequest>{body: {"message": "Category name cannot be empty"}};
            }

            map<json> objectId = self.createObjectId(categoryId);

            // Check if category exists and belongs to user
            stream<record {|anydata...;|}, error?> existingStream =
                check categoryCollection->find({_id: objectId, userId: userId});

            record {|anydata...;|}[] existing = [];
            check existingStream.forEach(function(record {|anydata...;|} cat) {
                existing.push(cat);
            });

            if (existing.length() == 0) {
                return <http:NotFound>{body: {"message": "Category not found"}};
            }

            mongodb:Update updateOperation = {
                set: {
                    name: updateData.name.trim(),
                    updatedAt: time:utcToString(time:utcNow())
                }
            };

            mongodb:UpdateResult _ = check categoryCollection->updateOne({_id: objectId, userId: userId}, updateOperation);

            return {"message": "Category updated successfully"};
        } on fail var e {
            return <http:InternalServerError>{body: {"message": "Failed to update category: " + e.toString()}};
        }
    }

    // Delete a category
    resource function delete categories/[string categoryId](@http:Header string Authorization)
            returns json|http:NotFound|http:InternalServerError|http:Unauthorized|http:Forbidden {

        map<json>|http:Unauthorized|http:Forbidden|error userIdResult = self.verifyTokenAndGetUserId(Authorization);
        if userIdResult is http:Unauthorized || userIdResult is http:Forbidden {
            return userIdResult;
        }
        if userIdResult is error {
            return <http:InternalServerError>{body: {"message": "Authentication failed"}};
        }

        map<json> userId = <map<json>>userIdResult;

        do {
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");
            mongodb:Collection linkCollection = check myDb->getCollection("links");

            map<json> objectId = self.createObjectId(categoryId);

            // Check if category exists and belongs to user
            stream<record {|anydata...;|}, error?> existingStream =
                check categoryCollection->find({_id: objectId, userId: userId});

            record {|anydata...;|}[] existing = [];
            check existingStream.forEach(function(record {|anydata...;|} cat) {
                existing.push(cat);
            });

            if (existing.length() == 0) {
                return <http:NotFound>{body: {"message": "Category not found"}};
            }

            // Delete all links in this category
            mongodb:DeleteResult _ = check linkCollection->deleteMany({categoryId: objectId, userId: userId});

            // Delete the category
            mongodb:DeleteResult _ = check categoryCollection->deleteOne({_id: objectId, userId: userId});

            return {"message": "Category and associated links deleted successfully"};
        } on fail var e {
            return <http:InternalServerError>{body: {"message": "Failed to delete category: " + e.toString()}};
        }
    }

    // =============== LINK CRUD OPERATIONS ===============

    // FIXED: Create a new link - Complete working version with proper array handling
    resource function post links(@http:Header string Authorization, LinkRequest linkData)
        returns json|http:BadRequest|http:InternalServerError|http:Unauthorized|http:Forbidden {

        map<json>|http:Unauthorized|http:Forbidden|error userIdResult = self.verifyTokenAndGetUserId(Authorization);
        if userIdResult is http:Unauthorized || userIdResult is http:Forbidden {
            return userIdResult;
        }
        if userIdResult is error {
            return <http:InternalServerError>{body: {"message": "Authentication failed"}};
        }

        map<json> userId = <map<json>>userIdResult;

        do {
            mongodb:Collection linkCollection = check myDb->getCollection("links");
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");

            if (linkData.name.trim().length() == 0) {
                return <http:BadRequest>{body: {"message": "Link name cannot be empty"}};
            }

            if (linkData.url.trim().length() == 0) {
                return <http:BadRequest>{body: {"message": "URL cannot be empty"}};
            }

            string cleanUrl = linkData.url.trim();
            if (!cleanUrl.startsWith("http://") && !cleanUrl.startsWith("https://")) {
                cleanUrl = "https://" + cleanUrl;
            }

            // Check if category exists and belongs to user
            map<json> categoryObjectId = self.createObjectId(linkData.categoryId);

            stream<record {|anydata...;|}, error?> categoryStream =
            check categoryCollection->find({_id: categoryObjectId, userId: userId});

            record {|anydata...;|}[] categories = [];
            check categoryStream.forEach(function(record {|anydata...;|} cat) {
                categories.push(cat);
            });

            if (categories.length() == 0) {
                return <http:BadRequest>{body: {"message": "Category not found"}};
            }

            string iconUrl = self.generateFaviconUrl(cleanUrl);

            // Create link document
            record {|
                string name;
                string url;
                string icon;
                map<json> categoryId;
                map<json> userId;
                string createdAt;
                string updatedAt;
            |} newLink = {
                name: linkData.name.trim(),
                url: cleanUrl,
                icon: iconUrl,
                categoryId: categoryObjectId,
                userId: userId,
                createdAt: time:utcToString(time:utcNow()),
                updatedAt: time:utcToString(time:utcNow())
            };

            // Insert the link first
            error? insertError = linkCollection->insertOne(newLink);
            if insertError is error {
                return <http:InternalServerError>{body: {"message": "Failed to insert link: " + insertError.toString()}};
            }

            // FIXED: Get the inserted link ID using a more reliable approach
            mongodb:FindOptions findOptions = {
                sort: {"_id": -1},
                'limit: 1
            };

            stream<record {|json _id; anydata...;|}, error?> insertedLinkStream =
            check linkCollection->find({
                name: newLink.name,
                url: newLink.url,
                categoryId: categoryObjectId,
                userId: userId
            }, findOptions);

            record {|json _id; anydata...;|}[] insertedLinks = [];
            check insertedLinkStream.forEach(function(record {|json _id; anydata...;|} link) {
                insertedLinks.push(link);
            });

            if (insertedLinks.length() > 0) {
                json linkId = insertedLinks[0]._id;

                if (linkId is ()) {
                    return <http:InternalServerError>{body: {"message": "Failed to get inserted link ID"}};
                }

                // FIXED: Get current category and properly handle the links array to preserve ALL existing links
                stream<record {|anydata...;|}, error?> currentCategoryStream =
                check categoryCollection->find({_id: categoryObjectId, userId: userId});

                record {|anydata...;|}[] currentCategories = [];
                check currentCategoryStream.forEach(function(record {|anydata...;|} cat) {
                    currentCategories.push(cat);
                });

                if (currentCategories.length() > 0) {
                    anydata currentLinksData = currentCategories[0]["links"];
                    json[] updatedLinks = [];

                    // FIXED: Handle existing links with proper type checking and conversion
                    if (currentLinksData is json[]) {
                        // If it's already a json array, copy all existing links one by one
                        foreach json existingLink in currentLinksData {
                            updatedLinks.push(existingLink);
                        }
                    } else if (currentLinksData is anydata[]) {
                        // Convert anydata array to json array carefully
                        foreach anydata existingLink in currentLinksData {
                            if (existingLink != ()) {
                                // Use cloneReadOnly to safely convert to json
                                json convertedLink = <json>existingLink.cloneReadOnly();
                                updatedLinks.push(convertedLink);
                            }
                        }
                    } else if (currentLinksData != ()) {
                        // Handle case where links might be a single value
                        json singleLink = <json>currentLinksData.cloneReadOnly();
                        updatedLinks.push(singleLink);
                    }
                    // If currentLinksData is (), updatedLinks remains empty array []

                    // Add the new link ID to the existing array
                    updatedLinks.push(linkId);

                    // Update the category with ALL existing links plus the new one
                    mongodb:Update categoryUpdate = {
                        set: {
                            "links": updatedLinks,
                            "updatedAt": time:utcToString(time:utcNow())
                        }
                    };

                    mongodb:UpdateResult updateResult = check categoryCollection->updateOne(
                    {_id: categoryObjectId, userId: userId},
                    categoryUpdate
                    );

                    // Verify the update was successful
                    if (updateResult.modifiedCount == 0) {
                        return <http:InternalServerError>{body: {"message": "Failed to update category with new link"}};
                    }
                } else {
                    return <http:InternalServerError>{body: {"message": "Category not found during update"}};
                }
            } else {
                return <http:InternalServerError>{body: {"message": "Failed to retrieve inserted link"}};
            }

            return {"message": "Link created successfully", "link": newLink};
        } on fail var e {
            return <http:InternalServerError>{body: {"message": "Failed to create link: " + e.toString()}};
        }
    }

    // Get links by category
    resource function get links/category/[string categoryId](@http:Header string Authorization)
            returns json[]|http:InternalServerError|http:Unauthorized|http:Forbidden {

        map<json>|http:Unauthorized|http:Forbidden|error userIdResult = self.verifyTokenAndGetUserId(Authorization);
        if userIdResult is http:Unauthorized || userIdResult is http:Forbidden {
            return userIdResult;
        }
        if userIdResult is error {
            return <http:InternalServerError>{body: {"message": "Authentication failed"}};
        }

        map<json> userId = <map<json>>userIdResult;

        do {
            mongodb:Collection linkCollection = check myDb->getCollection("links");
            map<json> categoryObjectId = self.createObjectId(categoryId);
            stream<record {|anydata...;|}, error?> linkStream =
                check linkCollection->find({categoryId: categoryObjectId, userId: userId});

            json[] links = [];
            check linkStream.forEach(function(record {|anydata...;|} link) {
                links.push(<json>link.cloneReadOnly());
            });

            return links;
        } on fail var e {
            return <http:InternalServerError>{body: {"message": "Failed to retrieve links: " + e.toString()}};
        }
    }

    // utility function 
    private function areObjectIdsEqual(json id1, json id2) returns boolean {
        if (id1 is map<json> && id2 is map<json>) {
            json? oid1 = id1["$oid"];
            json? oid2 = id2["$oid"];
            return oid1 is string && oid2 is string && oid1 == oid2;
        }
        return false;
    }

    // Update link function
    resource function put links/[string linkId](@http:Header string Authorization, LinkUpdate updateData)
        returns json|http:BadRequest|http:NotFound|http:InternalServerError|http:Unauthorized|http:Forbidden {

        map<json>|http:Unauthorized|http:Forbidden|error userIdResult = self.verifyTokenAndGetUserId(Authorization);
        if userIdResult is http:Unauthorized || userIdResult is http:Forbidden {
            return userIdResult;
        }
        if userIdResult is error {
            return <http:InternalServerError>{body: {"message": "Authentication failed"}};
        }

        map<json> userId = <map<json>>userIdResult;

        do {
            mongodb:Collection linkCollection = check myDb->getCollection("links");
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");

            map<json> linkObjectId = self.createObjectId(linkId);

            stream<record {|anydata...;|}, error?> existingStream =
            check linkCollection->find({_id: linkObjectId, userId: userId});

            record {|anydata...;|}[] existing = [];
            check existingStream.forEach(function(record {|anydata...;|} link) {
                existing.push(link);
            });

            if (existing.length() == 0) {
                return <http:NotFound>{body: {"message": "Link not found"}};
            }

            record {|anydata...;|} currentLink = existing[0];

            // FIXED: Safe type conversion
            anydata currentCategoryData = currentLink["categoryId"];
            json? currentCategoryId = ();
            if (currentCategoryData is json) {
                currentCategoryId = currentCategoryData;
            } else if (currentCategoryData is map<anydata>) {
                currentCategoryId = <json>currentCategoryData.cloneReadOnly();
            }

            map<json> updateFields = {
                updatedAt: time:utcToString(time:utcNow())
            };

            if (updateData?.name is string) {
                string name = <string>updateData?.name;
                if (name.trim().length() == 0) {
                    return <http:BadRequest>{body: {"message": "Link name cannot be empty"}};
                }
                updateFields["name"] = name.trim();
            }

            if (updateData?.url is string) {
                string inputUrl = <string>updateData?.url;
                if (inputUrl.trim().length() == 0) {
                    return <http:BadRequest>{body: {"message": "URL cannot be empty"}};
                }

                string cleanUrl = inputUrl.trim();
                if (!cleanUrl.startsWith("http://") && !cleanUrl.startsWith("https://")) {
                    cleanUrl = "https://" + cleanUrl;
                }

                updateFields["url"] = cleanUrl;
                updateFields["icon"] = self.generateFaviconUrl(cleanUrl);
            }

            if (updateData?.categoryId is string) {
                string categoryId = <string>updateData?.categoryId;
                map<json> newCategoryObjectId = self.createObjectId(categoryId);

                stream<record {|anydata...;|}, error?> categoryStream =
                check categoryCollection->find({_id: newCategoryObjectId, userId: userId});

                record {|anydata...;|}[] categories = [];
                check categoryStream.forEach(function(record {|anydata...;|} cat) {
                    categories.push(cat);
                });

                if (categories.length() == 0) {
                    return <http:BadRequest>{body: {"message": "Category not found"}};
                }

                if (currentCategoryId is json && !self.areObjectIdsEqual(currentCategoryId, newCategoryObjectId)) {
                    // Remove from old category
                    stream<record {|anydata...;|}, error?> oldCategoryStream =
                    check categoryCollection->find({_id: currentCategoryId, userId: userId});

                    record {|anydata...;|}[] oldCategories = [];
                    check oldCategoryStream.forEach(function(record {|anydata...;|} cat) {
                        oldCategories.push(cat);
                    });

                    if (oldCategories.length() > 0) {
                        anydata oldLinksData = oldCategories[0]["links"];
                        json[] updatedOldLinks = [];

                        if (oldLinksData is json[]) {
                            foreach json existingLink in oldLinksData {
                                if (!self.areObjectIdsEqual(existingLink, linkObjectId)) {
                                    updatedOldLinks.push(existingLink);
                                }
                            }
                        } else if (oldLinksData is anydata[]) {
                            foreach anydata existingLink in oldLinksData {
                                if (existingLink != ()) {
                                    json convertedLink = <json>existingLink.cloneReadOnly();
                                    if (!self.areObjectIdsEqual(convertedLink, linkObjectId)) {
                                        updatedOldLinks.push(convertedLink);
                                    }
                                }
                            }
                        }

                        mongodb:Update oldCategoryUpdate = {
                            set: {
                                "links": updatedOldLinks,
                                "updatedAt": time:utcToString(time:utcNow())
                            }
                        };
                        mongodb:UpdateResult _ = check categoryCollection->updateOne({_id: currentCategoryId, userId: userId}, oldCategoryUpdate);
                    }

                    // Add to new category
                    stream<record {|anydata...;|}, error?> newCategoryStream =
                    check categoryCollection->find({_id: newCategoryObjectId, userId: userId});

                    record {|anydata...;|}[] newCategories = [];
                    check newCategoryStream.forEach(function(record {|anydata...;|} cat) {
                        newCategories.push(cat);
                    });

                    if (newCategories.length() > 0) {
                        anydata newLinksData = newCategories[0]["links"];
                        json[] updatedNewLinks = [];

                        if (newLinksData is json[]) {
                            foreach json existingLink in newLinksData {
                                updatedNewLinks.push(existingLink);
                            }
                        } else if (newLinksData is anydata[]) {
                            foreach anydata existingLink in newLinksData {
                                if (existingLink != ()) {
                                    json convertedLink = <json>existingLink.cloneReadOnly();
                                    updatedNewLinks.push(convertedLink);
                                }
                            }
                        }

                        updatedNewLinks.push(linkObjectId);

                        mongodb:Update newCategoryUpdate = {
                            set: {
                                "links": updatedNewLinks,
                                "updatedAt": time:utcToString(time:utcNow())
                            }
                        };
                        mongodb:UpdateResult _ = check categoryCollection->updateOne({_id: newCategoryObjectId, userId: userId}, newCategoryUpdate);
                    }
                }

                updateFields["categoryId"] = newCategoryObjectId;
            }

            mongodb:Update updateOperation = {set: updateFields};
            mongodb:UpdateResult _ = check linkCollection->updateOne({_id: linkObjectId, userId: userId}, updateOperation);

            return {"message": "Link updated successfully"};
        } on fail var e {
            return <http:InternalServerError>{body: {"message": "Failed to update link: " + e.toString()}};
        }
    }

    // Delete link function
    resource function delete links/[string linkId](@http:Header string Authorization)
        returns json|http:NotFound|http:InternalServerError|http:Unauthorized|http:Forbidden {

        map<json>|http:Unauthorized|http:Forbidden|error userIdResult = self.verifyTokenAndGetUserId(Authorization);
        if userIdResult is http:Unauthorized || userIdResult is http:Forbidden {
            return userIdResult;
        }
        if userIdResult is error {
            return <http:InternalServerError>{body: {"message": "Authentication failed"}};
        }

        map<json> userId = <map<json>>userIdResult;

        do {
            mongodb:Collection linkCollection = check myDb->getCollection("links");
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");

            map<json> linkObjectId = self.createObjectId(linkId);

            stream<record {|anydata...;|}, error?> existingStream =
            check linkCollection->find({_id: linkObjectId, userId: userId});

            record {|anydata...;|}[] existing = [];
            check existingStream.forEach(function(record {|anydata...;|} link) {
                existing.push(link);
            });

            if (existing.length() == 0) {
                return <http:NotFound>{body: {"message": "Link not found"}};
            }

            // FIXED: Safe type conversion
            record {|anydata...;|} linkToDelete = existing[0];
            anydata categoryData = linkToDelete["categoryId"];
            json? categoryId = ();

            if (categoryData is json) {
                categoryId = categoryData;
            } else if (categoryData is map<anydata>) {
                categoryId = <json>categoryData.cloneReadOnly();
            }

            mongodb:DeleteResult deleteResult = check linkCollection->deleteOne({_id: linkObjectId, userId: userId});

            if (deleteResult.deletedCount > 0 && categoryId is json) {
                stream<record {|anydata...;|}, error?> categoryStream =
                check categoryCollection->find({_id: categoryId, userId: userId});

                record {|anydata...;|}[] categories = [];
                check categoryStream.forEach(function(record {|anydata...;|} cat) {
                    categories.push(cat);
                });

                if (categories.length() > 0) {
                    anydata currentLinksData = categories[0]["links"];
                    json[] updatedLinks = [];

                    if (currentLinksData is json[]) {
                        foreach json existingLink in currentLinksData {
                            if (!self.areObjectIdsEqual(existingLink, linkObjectId)) {
                                updatedLinks.push(existingLink);
                            }
                        }
                    } else if (currentLinksData is anydata[]) {
                        foreach anydata existingLink in currentLinksData {
                            if (existingLink != ()) {
                                json convertedLink = <json>existingLink.cloneReadOnly();
                                if (!self.areObjectIdsEqual(convertedLink, linkObjectId)) {
                                    updatedLinks.push(convertedLink);
                                }
                            }
                        }
                    }

                    mongodb:Update categoryUpdate = {
                        set: {
                            "links": updatedLinks,
                            "updatedAt": time:utcToString(time:utcNow())
                        }
                    };
                    mongodb:UpdateResult _ = check categoryCollection->updateOne({_id: categoryId, userId: userId}, categoryUpdate);
                }
            }

            return {"message": "Link deleted successfully"};
        } on fail var e {
            return <http:InternalServerError>{body: {"message": "Failed to delete link: " + e.toString()}};
        }
    }

    // =============== SEARCH FUNCTIONALITY ===============

    // Search links and categories
    resource function get search(@http:Header string Authorization, string query)
            returns json|http:BadRequest|http:InternalServerError|http:Unauthorized|http:Forbidden {

        if (query.trim().length() == 0) {
            return <http:BadRequest>{body: {"message": "Search query cannot be empty"}};
        }

        map<json>|http:Unauthorized|http:Forbidden|error userIdResult = self.verifyTokenAndGetUserId(Authorization);
        if userIdResult is http:Unauthorized || userIdResult is http:Forbidden {
            return userIdResult;
        }
        if userIdResult is error {
            return <http:InternalServerError>{body: {"message": "Authentication failed"}};
        }

        map<json> userId = <map<json>>userIdResult;

        do {
            mongodb:Collection linkCollection = check myDb->getCollection("links");
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");

            string searchQuery = query.trim();

            map<json> linkFilter = {
                userId: userId,
                "$or": [
                    {"name": {"$regex": searchQuery, "$options": "i"}},
                    {"url": {"$regex": searchQuery, "$options": "i"}}
                ]
            };

            stream<record {|anydata...;|}, error?> linkStream =
                check linkCollection->find(linkFilter);
            json[] foundLinks = [];
            check linkStream.forEach(function(record {|anydata...;|} link) {
                foundLinks.push(<json>link.cloneReadOnly());
            });

            map<json> categoryFilter = {
                userId: userId,
                "name": {"$regex": searchQuery, "$options": "i"}
            };

            stream<record {|anydata...;|}, error?> categoryStream =
                check categoryCollection->find(categoryFilter);
            json[] foundCategories = [];
            check categoryStream.forEach(function(record {|anydata...;|} category) {
                foundCategories.push(<json>category.cloneReadOnly());
            });

            return {links: foundLinks, categories: foundCategories};
        } on fail var e {
            return <http:InternalServerError>{body: {"message": "Search operation failed: " + e.toString()}};
        }
    }

    // =============== UTILITY ENDPOINTS ===============

    // Get statistics for authenticated user
    resource function get stats(@http:Header string Authorization)
            returns json|http:InternalServerError|http:Unauthorized|http:Forbidden {

        map<json>|http:Unauthorized|http:Forbidden|error userIdResult = self.verifyTokenAndGetUserId(Authorization);
        if userIdResult is http:Unauthorized || userIdResult is http:Forbidden {
            return userIdResult;
        }
        if userIdResult is error {
            return <http:InternalServerError>{body: {"message": "Authentication failed"}};
        }

        map<json> userId = <map<json>>userIdResult;

        do {
            mongodb:Collection linkCollection = check myDb->getCollection("links");
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");

            int totalLinks = check linkCollection->countDocuments({userId: userId});
            int totalCategories = check categoryCollection->countDocuments({userId: userId});

            return {
                "totalLinks": totalLinks,
                "totalCategories": totalCategories,
                "timestamp": time:utcToString(time:utcNow())
            };
        } on fail var e {
            return <http:InternalServerError>{body: {"message": "Failed to retrieve statistics: " + e.toString()}};
        }
    }

    // Export all user data
    resource function get export(@http:Header string Authorization)
            returns json|http:InternalServerError|http:Unauthorized|http:Forbidden {

        map<json>|http:Unauthorized|http:Forbidden|error userIdResult = self.verifyTokenAndGetUserId(Authorization);
        if userIdResult is http:Unauthorized || userIdResult is http:Forbidden {
            return userIdResult;
        }
        if userIdResult is error {
            return <http:InternalServerError>{body: {"message": "Authentication failed"}};
        }

        map<json> userId = <map<json>>userIdResult;

        do {
            mongodb:Collection linkCollection = check myDb->getCollection("links");
            mongodb:Collection categoryCollection = check myDb->getCollection("categories");

            stream<record {|anydata...;|}, error?> categoryStream =
                check categoryCollection->find({userId: userId});
            json[] categories = [];
            check categoryStream.forEach(function(record {|anydata...;|} category) {
                categories.push(<json>category.cloneReadOnly());
            });

            stream<record {|anydata...;|}, error?> linkStream =
                check linkCollection->find({userId: userId});
            json[] links = [];
            check linkStream.forEach(function(record {|anydata...;|} link) {
                links.push(<json>link.cloneReadOnly());
            });

            return {
                "exportDate": time:utcToString(time:utcNow()),
                "userId": self.extractObjectId(userId),
                "categories": categories,
                "links": links
            };
        } on fail var e {
            return <http:InternalServerError>{body: {"message": "Failed to export data: " + e.toString()}};
        }
    }
}
