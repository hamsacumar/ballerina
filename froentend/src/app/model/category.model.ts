export interface Category {
  _id?: string;      // MongoDB ObjectId
  name: string;
  userId?: any;      // stored as object in backend
  links?: string[];
  createdAt?: string;
  updatedAt?: string;
}
