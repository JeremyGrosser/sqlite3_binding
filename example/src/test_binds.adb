with Ada.Text_IO;
with Interfaces;
with Sqlite;

--  Exercises Bind_Long_Float, Bind_Null, Changes and Last_Insert_Row_Id
--  against an in-memory database. Prints PASS or raises.
procedure Test_Binds is
   use type Sqlite.Result_Code;
   use type Sqlite.Value_Type;
   use type Interfaces.Integer_64;

   DB   : Sqlite.Connection;
   Stmt : Sqlite.Statement;

   procedure Check
      (Condition : Boolean;
       Message   : String)
   is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Check;
begin
   Sqlite.Initialize;
   DB := Sqlite.Open (":memory:", (READWRITE => True, CREATE => True, others => False));
   Sqlite.Exec (DB, "CREATE TABLE t (id INTEGER PRIMARY KEY, x REAL)");

   Stmt := Sqlite.Prepare (DB, "INSERT INTO t (x) VALUES (?)");
   Sqlite.Bind_Long_Float (DB, Stmt, 1, 0.1);
   Check (Sqlite.Step (DB, Stmt) = Sqlite.SQLITE_DONE, "insert float");
   Check (Sqlite.Last_Insert_Row_Id (DB) = 1, "rowid 1");
   Sqlite.Reset (DB, Stmt);
   Sqlite.Bind_Null (DB, Stmt, 1);
   Check (Sqlite.Step (DB, Stmt) = Sqlite.SQLITE_DONE, "insert null");
   Check (Sqlite.Last_Insert_Row_Id (DB) = 2, "rowid 2");
   Sqlite.Finalize (DB, Stmt);

   Stmt := Sqlite.Prepare (DB, "SELECT x FROM t ORDER BY id");
   Check (Sqlite.Step (DB, Stmt) = Sqlite.SQLITE_ROW, "row 1");
   Check (Sqlite.Column_Type (Stmt, 0) = Sqlite.SQLITE_FLOAT, "float type");
   Check (Sqlite.To_Long_Float (Stmt, 0) = 0.1, "float value round trips");
   Check (Sqlite.Step (DB, Stmt) = Sqlite.SQLITE_ROW, "row 2");
   Check (Sqlite.Is_Null (Stmt, 0), "null value");
   Sqlite.Finalize (DB, Stmt);

   Sqlite.Exec (DB, "UPDATE t SET x = 2.5");
   Check (Sqlite.Changes (DB) = 2, "changes after update");
   Sqlite.Exec (DB, "DELETE FROM t WHERE id = 1");
   Check (Sqlite.Changes (DB) = 1, "changes after delete");

   Sqlite.Close (DB);
   Ada.Text_IO.Put_Line ("PASS");
end Test_Binds;
