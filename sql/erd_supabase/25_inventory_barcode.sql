-- 25_inventory_barcode.sql
-- Add unique barcode column to inventory_products

alter table public.inventory_products
add column if not exists barcode text;

create unique index if not exists idx_inventory_products_barcode 
on public.inventory_products(barcode) 
where barcode is not null and barcode != '';

