-- Insert medkit item into VORP items table
INSERT INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`) VALUES
('medkit', 'Medical Kit', 5, 1, 'item_standard', 1);

-- Optional: If you want to add it to a shop, uncomment and modify the following:
-- INSERT INTO `store_items` (`store`, `item`, `price`, `amount`) VALUES
-- ('doctor', 'medkit', 25.00, 10);
