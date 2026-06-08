-- ============================================================
-- matchmaking_queue テーブル作成 + room_id 列追加
-- Supabase SQL Editor で実行してください
-- ============================================================

-- ① テーブルが存在しない場合は新規作成（room_id 列を含む）
CREATE TABLE IF NOT EXISTS matchmaking_queue (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid        REFERENCES auth.users NOT NULL,
    rating              integer     NOT NULL DEFAULT 1500,
    nickname            text,
    matching_strength   text        NOT NULL DEFAULT 'same',
    time_limit          integer     NOT NULL DEFAULT 600,
    byoyomi             integer     NOT NULL DEFAULT 0,
    spectate_allowed    boolean     NOT NULL DEFAULT true,
    peer_id             text        NOT NULL,
    status              text        NOT NULL DEFAULT 'waiting',
    room_id             text,
    created_at          timestamptz DEFAULT now()
);

-- ② テーブルが既に存在していた場合は room_id 列だけ追加
ALTER TABLE matchmaking_queue ADD COLUMN IF NOT EXISTS room_id text;

-- ③ RLS（Row Level Security）
ALTER TABLE matchmaking_queue ENABLE ROW LEVEL SECURITY;

-- ④ ポリシー（既存があれば無視）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename  = 'matchmaking_queue'
          AND policyname = 'mm_select_all'
    ) THEN
        CREATE POLICY "mm_select_all" ON matchmaking_queue FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename  = 'matchmaking_queue'
          AND policyname = 'mm_insert_own'
    ) THEN
        CREATE POLICY "mm_insert_own" ON matchmaking_queue FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename  = 'matchmaking_queue'
          AND policyname = 'mm_update_own'
    ) THEN
        CREATE POLICY "mm_update_own" ON matchmaking_queue FOR UPDATE USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename  = 'matchmaking_queue'
          AND policyname = 'mm_delete_own'
        ) THEN
        CREATE POLICY "mm_delete_own" ON matchmaking_queue FOR DELETE USING (auth.uid() = user_id);
    END IF;
END $$;
