import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerinax/mongodb;

// Collection names
const string USERS_COLLECTION = "users";
const string LINKS_COLLECTION = "links";

// User record type from users collection
type detailsUser record {
    string _id;
    string email;
    string name;
    string createdAt?;
};

// Link record type from links collection
type userLink record {
    string _id?;
    string userId; // Reference to user's _id
    string url;
    string category;
    string createdAt?;
    string updatedAt?;
};

// Admin dashboard user details response
type AdminUserDetail record {
    string userId;
    string name;
    string email;
    string createdAt;
    int linksCount;
    int categoriesCount;
    string lastUpdated;
    string[] categories;
    Link[] recentLinks;
};

// Summary statistics response
type AdminSummary record {
    int totalUsers;
    int totalLinks;
    int totalCategories;
    string lastActivity;
};

// Error response type
type ErrorResponse record {
    string message;
    string 'error;
};

// Specific response types to avoid ambiguity
type UserDetailResponse record {
    detailsUser user;
    record {
        int totalLinks;
        int totalCategories;
        string[] categories;
    } statistics;
    map<Link[]> linksByCategory;
    Link[] allLinks;
};

type CategoryAnalyticsResponse record {
    int totalCategories;
    json[] categoryBreakdown;
};

type TimelineResponse record {
    string period;
    json[] timeline;
};

type SearchResponse record {
    AdminUserDetail[] users;
    record {
        int page;
        int 'limit;
        int total;
        int totalPages;
    } pagination;
};

@http:ServiceConfig {
    cors: {
        allowOrigins: ["http://localhost:4200"],
        allowCredentials: false,
        allowHeaders: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    }
}

// Admin service
service /admin on new http:Listener(9093) {

    // Health check endpoint
    resource function get health() returns json {
        time:Utc currentTime = time:utcNow();
        return {
            "status": "UP",
            "service": "Admin Backend Service",
            "timestamp": time:utcToString(currentTime),
            "database": "ballerina"
        };
    }

    // Get all users with their statistics for admin dashboard
    resource function get users() returns AdminUserDetail[]|ErrorResponse {
        do {
            mongodb:Collection usersCollection = check myDb->getCollection(USERS_COLLECTION);
            mongodb:Collection linksCollection = check myDb->getCollection(LINKS_COLLECTION);

            // Get all users
            stream<detailsUser, error?> usersStream = check usersCollection->find();
            detailsUser[] users = [];
            
            check usersStream.forEach(function(detailsUser user) {
                users.push(user);
            });

            AdminUserDetail[] adminUsers = [];

            // For each user, get their links statistics
            foreach detailsUser user in users {
                AdminUserDetail adminUser = check self.getUserStatistics(user, linksCollection);
                adminUsers.push(adminUser);
            }

            // Sort by most recent activity using array:sort with key function
            AdminUserDetail[] sortedUsers = from var user in adminUsers
                                          order by user.lastUpdated descending
                                          select user;

            return sortedUsers;

        } on fail error e {
            log:printError("Error fetching admin user details: " + e.message());
            return {
                message: "Failed to fetch user details",
                'error: e.message()
            };
        }
    }

    // Get specific user details with all their links
    resource function get users/[string userId]() returns UserDetailResponse|ErrorResponse {
        do {
            mongodb:Collection usersCollection = check myDb->getCollection(USERS_COLLECTION);
            mongodb:Collection linksCollection = check myDb->getCollection(LINKS_COLLECTION);

            // Get user details
            map<json> userFilter = {"_id": {"$oid": userId}};
            detailsUser? user = check usersCollection->findOne(userFilter);

            if user is () {
                return {
                    message: "User not found",
                    'error: "No user exists with the provided ID"
                };
            }

            // Get all links for this user
            map<json> linksFilter = {"userId": userId};
            mongodb:FindOptions linksOptions = {
                sort: {"updatedAt": -1}
            };

            stream<userLink, error?> linksStream = check linksCollection->find(linksFilter, linksOptions);
            Link[] userLinks = [];
            
            check linksStream.forEach(function(Link link) {
                userLinks.push(link);
            });

            // Get unique categories
            string[] uniqueCategories = [];
            foreach Link link in userLinks {
                if uniqueCategories.indexOf(link.category) == () {
                    uniqueCategories.push(link.category);
                }
            }

            // Group links by category
            map<Link[]> linksByCategory = {};
            foreach Link link in userLinks {
                if !linksByCategory.hasKey(link.category) {
                    linksByCategory[link.category] = [];
                }
                Link[]? categoryLinks = linksByCategory[link.category];
                if categoryLinks is Link[] {
                    categoryLinks.push(link);
                }
            }

            return {
                user: user,
                statistics: {
                    totalLinks: userLinks.length(),
                    totalCategories: uniqueCategories.length(),
                    categories: uniqueCategories
                },
                linksByCategory: linksByCategory,
                allLinks: userLinks
            };

        } on fail error e {
            log:printError("Error fetching user details: " + e.message());
            return {
                message: "Failed to fetch user details",
                'error: e.message()
            };
        }
    }

    // Get admin dashboard summary
    resource function get summary() returns AdminSummary|ErrorResponse {
        do {
            mongodb:Collection usersCollection = check myDb->getCollection(USERS_COLLECTION);
            mongodb:Collection linksCollection = check myDb->getCollection(LINKS_COLLECTION);

            // Count total users
            int totalUsers = check usersCollection->countDocuments({});

            // Count total links
            int totalLinks = check linksCollection->countDocuments({});

            // Get unique categories count using aggregation
            map<json>[] categoryPipeline = [
                {
                    "$group": {
                        "_id": "$category"
                    }
                },
                {
                    "$count": "totalCategories"
                }
            ];

            stream<json, error?> categoryResult = check linksCollection->aggregate(categoryPipeline);
            json[] categoryCount = [];
            check categoryResult.forEach(function(json result) {
                categoryCount.push(result);
            });

            int totalCategories = 0;
            if categoryCount.length() > 0 {
                json firstResult = categoryCount[0];
                if firstResult is map<json> && firstResult.hasKey("totalCategories") {
                    totalCategories = <int>firstResult["totalCategories"];
                }
            }

            // Get last activity (most recent link update)
            mongodb:FindOptions lastActivityOptions = {
                sort: {"updatedAt": -1},
                'limit: 1
            };

            stream<Link, error?> lastActivityStream = check linksCollection->find({}, lastActivityOptions);
            Link[] lastActivityLinks = [];
            
            check lastActivityStream.forEach(function(Link link) {
                lastActivityLinks.push(link);
            });

            string lastActivity = "No activity found";
            if lastActivityLinks.length() > 0 {
                lastActivity = lastActivityLinks[0].updatedAt ?: "Unknown";
            }

            return {
                totalUsers: totalUsers,
                totalLinks: totalLinks,
                totalCategories: totalCategories,
                lastActivity: lastActivity
            };

        } on fail error e {
            log:printError("Error fetching admin summary: " + e.message());
            return {
                message: "Failed to fetch admin summary",
                'error: e.message()
            };
        }
    }

    // Get category analytics
    resource function get analytics/categories() returns CategoryAnalyticsResponse|ErrorResponse {
        do {
            mongodb:Collection linksCollection = check myDb->getCollection(LINKS_COLLECTION);

            // Aggregation pipeline for category statistics
            map<json>[] pipeline = [
                {
                    "$group": {
                        "_id": "$category",
                        "linkCount": {"$sum": 1},
                        "users": {"$addToSet": "$userId"},
                        "lastUpdated": {"$max": "$updatedAt"}
                    }
                },
                {
                    "$project": {
                        "category": "$_id",
                        "linkCount": 1,
                        "userCount": {"$size": "$users"},
                        "lastUpdated": 1,
                        "_id": 0
                    }
                },
                {
                    "$sort": {"linkCount": -1}
                }
            ];

            stream<json, error?> result = check linksCollection->aggregate(pipeline);
            json[] categoryStats = [];
            
            check result.forEach(function(json stat) {
                categoryStats.push(stat);
            });

            return {
                totalCategories: categoryStats.length(),
                categoryBreakdown: categoryStats
            };

        } on fail error e {
            log:printError("Error fetching category analytics: " + e.message());
            return {
                message: "Failed to fetch category analytics",
                'error: e.message()
            };
        }
    }

    // Get user activity timeline
    resource function get analytics/timeline(int days = 30) returns TimelineResponse|ErrorResponse {
        do {
            mongodb:Collection linksCollection = check myDb->getCollection(LINKS_COLLECTION);

            // Calculate date range
            time:Utc currentTime = time:utcNow();
            time:Utc startDate = time:utcAddSeconds(currentTime, -days * 24 * 60 * 60);
            string startDateStr = time:utcToString(startDate);

            // Aggregation pipeline for daily activity
            map<json>[] pipeline = [
                {
                    "$match": {
                        "createdAt": {"$gte": startDateStr}
                    }
                },
                {
                    "$group": {
                        "_id": {
                            "$dateToString": {
                                "format": "%Y-%m-%d",
                                "date": {"$dateFromString": {"dateString": "$createdAt"}}
                            }
                        },
                        "linksCreated": {"$sum": 1},
                        "activeUsers": {"$addToSet": "$userId"}
                    }
                },
                {
                    "$project": {
                        "date": "$_id",
                        "linksCreated": 1,
                        "activeUsers": {"$size": "$activeUsers"},
                        "_id": 0
                    }
                },
                {
                    "$sort": {"date": 1}
                }
            ];

            stream<json, error?> result = check linksCollection->aggregate(pipeline);
            json[] timelineData = [];
            
            check result.forEach(function(json data) {
                timelineData.push(data);
            });

            return {
                period: string `Last ${days} days`,
                timeline: timelineData
            };

        } on fail error e {
            log:printError("Error fetching timeline analytics: " + e.message());
            return {
                message: "Failed to fetch timeline analytics",
                'error: e.message()
            };
        }
    }

    // Search users by name or email
    resource function get search(string? query, int page = 1, int 'limit = 10) returns SearchResponse|ErrorResponse {
        do {
            mongodb:Collection usersCollection = check myDb->getCollection(USERS_COLLECTION);

            map<json> filter = {};
            if query is string && query.trim() != "" {
                filter = {
                    "$or": [
                        {"name": {"$regex": query, "$options": "i"}},
                        {"email": {"$regex": query, "$options": "i"}}
                    ]
                };
            }

            // Calculate pagination
            int skip = (page - 1) * 'limit;

            // Count total documents
            int totalCount = check usersCollection->countDocuments(filter);

            // Find with pagination
            mongodb:FindOptions options = {
                sort: {"createdAt": -1},
                'limit: 'limit,
                skip: skip
            };

            stream<detailsUser, error?> usersStream = check usersCollection->find(filter, options);
            detailsUser[] users = [];
            
            check usersStream.forEach(function(detailsUser user) {
                users.push(user);
            });

            // Get statistics for each user
            AdminUserDetail[] adminUsers = [];
            mongodb:Collection linksCollection = check myDb->getCollection(LINKS_COLLECTION);

            foreach detailsUser user in users {
                AdminUserDetail adminUser = check self.getUserStatistics(user, linksCollection);
                adminUsers.push(adminUser);
            }

            return {
                users: adminUsers,
                pagination: {
                    page: page,
                    'limit: 'limit,
                    total: totalCount,
                    totalPages: (totalCount + 'limit - 1) / 'limit
                }
            };

        } on fail error e {
            log:printError("Error searching users: " + e.message());
            return {
                message: "Failed to search users",
                'error: e.message()
            };
        }
    }

    // Private function to get user statistics
    private function getUserStatistics(detailsUser user, mongodb:Collection linksCollection) returns AdminUserDetail|error {
        
        // Get user's links
        map<json> linksFilter = {"userId": user._id};
        mongodb:FindOptions linksOptions = {
            sort: {"updatedAt": -1}
        };

        stream<Link, error?> linksStream = check linksCollection->find(linksFilter, linksOptions);
        Link[] userLinks = [];
        
        check linksStream.forEach(function(Link link) {
            userLinks.push(link);
        });

        // Calculate statistics
        int linksCount = userLinks.length();
        
        // Get unique categories
        string[] uniqueCategories = [];
        foreach Link link in userLinks {
            if uniqueCategories.indexOf(link.category) == () {
                uniqueCategories.push(link.category);
            }
        }
        int categoriesCount = uniqueCategories.length();

        // Get last updated time
        string lastUpdated = user.createdAt ?: "Unknown";
        if userLinks.length() > 0 {
            lastUpdated = userLinks[0].updatedAt ?: lastUpdated;
        }

        // Get recent links (last 5)
        Link[] recentLinks = [];
        int maxRecent = userLinks.length() < 5 ? userLinks.length() : 5;
        int i = 0;
        while i < maxRecent {
            recentLinks.push(userLinks[i]);
            i += 1;
        }

        return {
            userId: user._id,
            name: user.name,
            email: user.email,
            createdAt: user.createdAt ?: "Unknown",
            linksCount: linksCount,
            categoriesCount: categoriesCount,
            lastUpdated: lastUpdated,
            categories: uniqueCategories,
            recentLinks: recentLinks
        };
    }
}