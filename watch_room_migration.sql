-- matchmaking_queue に room_id 列を追加（観戦機能用）
-- Supabase SQL Editor で実行してください
ALTER TABLE matchmaking_queue ADD COLUMN IF NOT EXISTS room_id text;
