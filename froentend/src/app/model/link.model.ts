export interface Link {
  _id?: string;
  name: string;
  url: string;
  icon?: string;
  categoryId: string;
  userId?: any;
  createdAt?: string;
  updatedAt?: string;
    hashedUrl: string;   // ✅ add this

}
