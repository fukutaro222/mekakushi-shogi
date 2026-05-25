-- ============================================================
-- 掲示板テーブル一式 修正版 (Supabase SQL Editor で実行してください)
-- ============================================================

-- ── 既存ポリシーを安全に削除（テーブルが存在する場合のみ）────
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname='public' AND tablename='boards') THEN
        DROP POLICY IF EXISTS "brd_select"     ON boards;
        DROP POLICY IF EXISTS "brd_insert"     ON boards;
        DROP POLICY IF EXISTS "brd_update_own" ON boards;
    END IF;
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname='public' AND tablename='board_replies') THEN
        DROP POLICY IF EXISTS "brd_reply_select"     ON board_replies;
        DROP POLICY IF EXISTS "brd_reply_insert"     ON board_replies;
        DROP POLICY IF EXISTS "brd_reply_update_own" ON board_replies;
    END IF;
    -- board_reports はスキーマ不一致のため DROP して再作成
    DROP TABLE IF EXISTS board_reports CASCADE;
END $$;

-- ── boards テーブル（スレッド）────────────────────────────────
CREATE TABLE IF NOT EXISTS boards (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        REFERENCES auth.users NOT NULL,
    nickname    text,
    title       text        NOT NULL,
    content     text        NOT NULL,
    reply_count integer     DEFAULT 0,
    is_deleted  boolean     DEFAULT false,
    created_at  timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS boards_created_at_idx ON boards (created_at DESC);
ALTER TABLE boards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brd_select"     ON boards FOR SELECT USING (true);
CREATE POLICY "brd_insert"     ON boards FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "brd_update_own" ON boards FOR UPDATE USING (auth.uid() = user_id);

-- ── board_replies テーブル（返信）────────────────────────────
CREATE TABLE IF NOT EXISTS board_replies (
    id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id   uuid        REFERENCES boards NOT NULL,
    user_id    uuid        REFERENCES auth.users NOT NULL,
    nickname   text,
    content    text        NOT NULL,
    is_deleted boolean     DEFAULT false,
    created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS board_replies_board_id_idx ON board_replies (board_id, created_at);
ALTER TABLE board_replies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brd_reply_select"     ON board_replies FOR SELECT USING (true);
CREATE POLICY "brd_reply_insert"     ON board_replies FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "brd_reply_update_own" ON board_replies FOR UPDATE USING (auth.uid() = user_id);

-- ── board_reports テーブル（通報）────────────────────────────
-- ※ DO ブロックで DROP 済みのため IF NOT EXISTS なし
CREATE TABLE board_reports (
    id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id         uuid        REFERENCES boards,
    reply_id         uuid        REFERENCES board_replies,
    reporter_user_id uuid        REFERENCES auth.users NOT NULL,
    reason           text        NOT NULL,
    created_at       timestamptz DEFAULT now()
);
ALTER TABLE board_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brd_report_insert"     ON board_reports FOR INSERT WITH CHECK (auth.uid() = reporter_user_id);
CREATE POLICY "brd_report_select_own" ON board_reports FOR SELECT  USING (auth.uid() = reporter_user_id);

-- ── 重複通報防止（1ユーザー1投稿につき1回のみ）────────────────
CREATE UNIQUE INDEX board_reports_unique_board_per_user
    ON board_reports (board_id, reporter_user_id)
    WHERE board_id IS NOT NULL;

CREATE UNIQUE INDEX board_reports_unique_reply_per_user
    ON board_reports (reply_id, reporter_user_id)
    WHERE reply_id IS NOT NULL;

-- ── reply_count 自動更新トリガー（INSERT 時にインクリメント）──
CREATE OR REPLACE FUNCTION update_board_reply_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE boards SET reply_count = reply_count + 1 WHERE id = NEW.board_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS board_reply_count_trigger ON board_replies;
CREATE TRIGGER board_reply_count_trigger
    AFTER INSERT ON board_replies
    FOR EACH ROW EXECUTE FUNCTION update_board_reply_count();

-- ── 3件通報で自動非表示トリガー（SECURITY DEFINER で RLS を回避）
CREATE OR REPLACE FUNCTION auto_hide_on_reports()
RETURNS TRIGGER AS $$
DECLARE
    report_count INTEGER;
BEGIN
    IF NEW.board_id IS NOT NULL THEN
        SELECT COUNT(*) INTO report_count
            FROM board_reports WHERE board_id = NEW.board_id;
        IF report_count >= 3 THEN
            UPDATE boards SET is_deleted = true WHERE id = NEW.board_id;
        END IF;
    ELSIF NEW.reply_id IS NOT NULL THEN
        SELECT COUNT(*) INTO report_count
            FROM board_reports WHERE reply_id = NEW.reply_id;
        IF report_count >= 3 THEN
            UPDATE board_replies SET is_deleted = true WHERE id = NEW.reply_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS auto_hide_on_reports_trigger ON board_reports;
CREATE TRIGGER auto_hide_on_reports_trigger
    AFTER INSERT ON board_reports
    FOR EACH ROW EXECUTE FUNCTION auto_hide_on_reports();
