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

    // Helper function to extract YYYY-MM from createdAt timestamp
    private function extractMonth(string createdAt) returns string {
        // Handle different date formats: ISO string, timestamp, etc.
        // Expected format: "2024-01-15T10:30:00Z" or "2024-01-15"
        if createdAt.length() >= 7 {
            // Extract first 7 characters (YYYY-MM)
            return createdAt.substring(0, 7);
        }
        return "";
    }

    // Helper function to get current month in YYYY-MM format
    private function getCurrentMonth() returns string {
        time:Utc currentTime = time:utcNow();
        time:Civil civilTime = time:utcToCivil(currentTime);
        return string `${civilTime.year}-${civilTime.month < 10 ? "0" : ""}${civilTime.month}`;
    }

    // Helper function to get previous month in YYYY-MM format
    private function getPreviousMonth() returns string {
        time:Utc currentTime = time:utcNow();
        time:Civil civilTime = time:utcToCivil(currentTime);
        
        int prevMonth = civilTime.month - 1;
        int prevYear = civilTime.year;
        
        if prevMonth == 0 {
            prevMonth = 12;
            prevYear = prevYear - 1;
        }
        
        return string `${prevYear}-${prevMonth < 10 ? "0" : ""}${prevMonth}`;
    }

    // Helper function to generate all months from start to end (inclusive)
    private function generateMonthRange(string startMonth, string endMonth) returns string[]|error {
        string[] months = [];
        
        // Parse start month
        string:RegExp separator = re `-`;
        string[] startParts = separator.split(startMonth);
        string[] endParts = separator.split(endMonth);
        
        if startParts.length() != 2 || endParts.length() != 2 {
            return months;
        }
        
        int startYear = check int:fromString(startParts[0]);
        int startMonthNum = check int:fromString(startParts[1]);
        int endYear = check int:fromString(endParts[0]);
        int endMonthNum = check int:fromString(endParts[1]);
        
        int currentYear = startYear;
        int currentMonth = startMonthNum;
        
        while (currentYear < endYear || (currentYear == endYear && currentMonth <= endMonthNum)) {
            string monthStr = string `${currentYear}-${currentMonth < 10 ? "0" : ""}${currentMonth}`;
            months.push(monthStr);
            
            currentMonth += 1;
            if currentMonth > 12 {
                currentMonth = 1;
                currentYear += 1;
            }
        }
        
        return months;
    }

    // Helper function to find the earliest user creation month
    private function getEarliestUserMonth() returns string|error {
        mongodb:Collection userCollection = check myDb->getCollection("users");
        
        // Sort by createdAt ascending to get the earliest user
        mongodb:FindOptions options = {
            sort: {"createdAt": 1},
            'limit: 1
        };
        
        stream<record {|anydata...;|}, error?> userStream = check userCollection->find({}, options);
        
        string earliestMonth = self.getCurrentMonth(); // Default to current month
        
        check userStream.forEach(function(record {|anydata...;|} user) {
            anydata createdAtRaw = user["createdAt"];
            string createdAtStr = "";
            
            if createdAtRaw is string {
                createdAtStr = createdAtRaw;
            } else if createdAtRaw is map<anydata> {
                anydata dateValue = createdAtRaw["$date"];
                if dateValue is string {
                    createdAtStr = dateValue;
                }
            }
            
            if createdAtStr != "" {
                earliestMonth = self.extractMonth(createdAtStr);
            }
        });
        
        return earliestMonth;
    }

    // Helper function to convert YYYY-MM to readable month name
    private function getMonthName(string monthStr) returns string {
        string:RegExp separator = re `-`;
        string[] parts = separator.split(monthStr);
        if parts.length() != 2 {
            return monthStr;
        }
        
        string year = parts[0];
        string month = parts[1];
        
        string monthName = "";
        if month == "01" {
            monthName = "January";
        } else if month == "02" {
            monthName = "February";
        } else if month == "03" {
            monthName = "March";
        } else if month == "04" {
            monthName = "April";
        } else if month == "05" {
            monthName = "May";
        } else if month == "06" {
            monthName = "June";
        } else if month == "07" {
            monthName = "July";
        } else if month == "08" {
            monthName = "August";
        } else if month == "09" {
            monthName = "September";
        } else if month == "10" {
            monthName = "October";
        } else if month == "11" {
            monthName = "November";
        } else if month == "12" {
            monthName = "December";
        } else {
            monthName = month;
        }
        
        return monthName + " " + year;
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
   // Replace your existing counts() function with this monthly counts function
resource function get counts() returns json|http:InternalServerError {
    do {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        mongodb:Collection userCollection = check myDb->getCollection("users");

        // Get total counts
        int totalLinks = check linkCollection->countDocuments({});
        int totalCategories = check categoryCollection->countDocuments({});
        int totalUsers = check userCollection->countDocuments({});

        return {
            "summary": {
                "totalUsers": totalUsers,
                "totalLinks": totalLinks,
                "totalCategories": totalCategories
            },
            "message": "Counts retrieved successfully"
        };

    } on fail var e {
        log:printError("Counts error: " + e.toString());
        return <http:InternalServerError>{
            body: {"message": "Failed to get counts: " + e.toString()}
        };
    }
}


// Monthly bar chart data from first user creation to current month
resource function get monthlyBarChart() returns json|http:InternalServerError {
    do {
        mongodb:Collection linkCollection = check myDb->getCollection("links");
        mongodb:Collection categoryCollection = check myDb->getCollection("categories");
        mongodb:Collection userCollection = check myDb->getCollection("users");

        // Find the earliest user creation month
        string earliestMonth = check self.getEarliestUserMonth();
        string currentMonth = self.getCurrentMonth();
        
        // Generate all months from earliest to current
        string[] targetMonths = check self.generateMonthRange(earliestMonth, currentMonth);
        
        log:printInfo("Generating chart data from " + earliestMonth + " to " + currentMonth + " (" + targetMonths.length().toString() + " months)");

        // Get all documents and process manually
        stream<record {|anydata...;|}, error?> linksStream = check linkCollection->find({});
        stream<record {|anydata...;|}, error?> categoriesStream = check categoryCollection->find({});
        stream<record {|anydata...;|}, error?> usersStream = check userCollection->find({});

        // Maps to store monthly counts for all months
        map<int> linksMonthlyCount = {};
        map<int> categoriesMonthlyCount = {};
        map<int> usersMonthlyCount = {};

        // Initialize all months with 0 counts
        foreach string month in targetMonths {
            linksMonthlyCount[month] = 0;
            categoriesMonthlyCount[month] = 0;
            usersMonthlyCount[month] = 0;
        }

        // Process links
        check linksStream.forEach(function(record {|anydata...;|} link) {
            anydata createdAtRaw = link["createdAt"];
            string createdAtStr = "";
            
            if createdAtRaw is string {
                createdAtStr = createdAtRaw;
            } else if createdAtRaw is map<anydata> {
                // Handle MongoDB date object
                anydata dateValue = createdAtRaw["$date"];
                if dateValue is string {
                    createdAtStr = dateValue;
                }
            }
            
            if createdAtStr != "" {
                string month = self.extractMonth(createdAtStr);
                // Count for all months in our range
                if linksMonthlyCount.hasKey(month) {
                    linksMonthlyCount[month] = (linksMonthlyCount[month] ?: 0) + 1;
                }
            }
        });

        // Process categories
        check categoriesStream.forEach(function(record {|anydata...;|} category) {
            anydata createdAtRaw = category["createdAt"];
            string createdAtStr = "";
            
            if createdAtRaw is string {
                createdAtStr = createdAtRaw;
            } else if createdAtRaw is map<anydata> {
                // Handle MongoDB date object
                anydata dateValue = createdAtRaw["$date"];
                if dateValue is string {
                    createdAtStr = dateValue;
                }
            }
            
            if createdAtStr != "" {
                string month = self.extractMonth(createdAtStr);
                // Count for all months in our range
                if categoriesMonthlyCount.hasKey(month) {
                    categoriesMonthlyCount[month] = (categoriesMonthlyCount[month] ?: 0) + 1;
                }
            }
        });

        // Process users
        check usersStream.forEach(function(record {|anydata...;|} user) {
            anydata createdAtRaw = user["createdAt"];
            string createdAtStr = "";
            
            if createdAtRaw is string {
                createdAtStr = createdAtRaw;
            } else if createdAtRaw is map<anydata> {
                // Handle MongoDB date object
                anydata dateValue = createdAtRaw["$date"];
                if dateValue is string {
                    createdAtStr = dateValue;
                }
            }
            
            if createdAtStr != "" {
                string month = self.extractMonth(createdAtStr);
                // Count for all months in our range
                if usersMonthlyCount.hasKey(month) {
                    usersMonthlyCount[month] = (usersMonthlyCount[month] ?: 0) + 1;
                }
            }
        });

        // Create chart data for all months from earliest to current
        json[] chartData = [];
        foreach string month in targetMonths {
            int linkCount = linksMonthlyCount[month] ?: 0;
            int categoryCount = categoriesMonthlyCount[month] ?: 0;
            int userCount = usersMonthlyCount[month] ?: 0;

            json monthData = {
                "x": self.getMonthName(month),
                "month": month,
                "links": linkCount,
                "categories": categoryCount,
                "users": userCount,
                "total": linkCount + categoryCount + userCount,
                "isCurrent": month == currentMonth
            };
            chartData.push(monthData);
        }

        return {
            "chartData": chartData,
            "chartConfig": {
                "xAxisKey": "x",
                "dataKeys": ["links", "categories", "users"],
                "colors": {
                    "links": "#F4A460",
                    "categories": "#4169E1",
                    "users": "#DC143C"
                },
                "labels": {
                    "links": "Links",
                    "categories": "Categories", 
                    "users": "Users"
                }
            },
            "summary": {
                "totalMonths": targetMonths.length(),
                "startMonth": self.getMonthName(earliestMonth),
                "endMonth": self.getMonthName(currentMonth)
            },
            "message": "Monthly bar chart data retrieved successfully from " + self.getMonthName(earliestMonth) + " to " + self.getMonthName(currentMonth)
        };

    } on fail var e {
        log:printError("Monthly bar chart error: " + e.toString());
        return <http:InternalServerError>{
            body: {"message": "Failed to get monthly bar chart data: " + e.toString()}
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