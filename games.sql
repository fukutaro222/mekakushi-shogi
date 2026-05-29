-- games テーブル再作成（既存テーブルを削除して作り直す）
DROP TABLE IF EXISTS games CASCADE;

CREATE TABLE games (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    sente_id            uuid        REFERENCES auth.users,
    gote_id             uuid        REFERENCES auth.users,
    sente_nickname      text,
    gote_nickname       text,
    winner              text,
    moves_count         integer,
    kifu                jsonb,
    game_type           text,
    game_mode           text,
    sente_rating_before integer,
    gote_rating_before  integer,
    sente_rating_after  integer,
    gote_rating_after   integer,
    created_at          timestamptz DEFAULT now()
);

CREATE INDEX games_sente_id_idx ON games (sente_id, created_at DESC);
CREATE INDEX games_gote_id_idx  ON games (gote_id,  created_at DESC);

ALTER TABLE games ENABLE ROW LEVEL SECURITY;

CREATE POLICY "games_select_all" ON games FOR SELECT USING (true);
CREATE POLICY "games_insert_own" ON games FOR INSERT WITH CHECK (
    auth.uid() = sente_id OR auth.uid() = gote_id
);
