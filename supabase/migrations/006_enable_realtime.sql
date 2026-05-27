-- Enable Realtime on donor_responses table
ALTER TABLE donor_responses REPLICA IDENTITY FULL;
-- Supabase UI will be used to enable realtime on the table
-- This is just to ensure the table is ready for it.

-- Safely add the table to the publication or create it if not exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime FOR TABLE donor_responses;
  ELSE
    ALTER PUBLICATION supabase_realtime ADD TABLE donor_responses;
  END IF;
EXCEPTION
  WHEN duplicate_object OR duplicate_table THEN
    NULL;
  WHEN OTHERS THEN
    NULL;
END $$;
