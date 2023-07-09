pragma Extensions_Allowed (On);
with Ada.Containers.Indefinite_Holders;
with Ada.Text_IO;
with Sqlite;

procedure Example is
   use type Sqlite.Result_Code;

   Flags : constant Sqlite.Open_Flags :=
      (NOMUTEX => True,
       others  => False);

   DB : Sqlite.Connection := null;
   Stmt : Sqlite.Statement := null;

   Query : constant String := "SELECT " &
      "   ProductID, ProductName, UnitPrice " &
      "FROM " &
      "   Products " &
      "WHERE " &
      "   Discontinued=0 AND" &
      "   CategoryID=? AND" &
      "   ProductName LIKE ?" &
      "ORDER BY " &
      "   UnitPrice DESC";

   package SH is new Ada.Containers.Indefinite_Holders (String);

   type Product is record
      ID    : Natural;
      Name  : SH.Holder;
      Price : Positive;
   end record;

   P : Product;
begin
   Sqlite.Initialize;
   DB := Sqlite.Open ("northwind.db", Flags);
   Stmt := Sqlite.Prepare (DB, Query);

   Sqlite.Reset (DB, Stmt);
   Sqlite.Bind_Text (DB, Stmt, 1, "1");
   Sqlite.Bind_Text (DB, Stmt, 2, "%Coffee%");

   loop
      exit when Sqlite.Step (DB, Stmt) /= Sqlite.SQLITE_ROW;
      P.ID := Sqlite.To_Integer (Stmt, 0);
      P.Name := SH.To_Holder (Sqlite.To_String (Stmt, 1));
      P.Price := Sqlite.To_Integer (Stmt, 2);
      Ada.Text_IO.Put_Line (P'Image);
   end loop;

   Sqlite.Finalize (DB, Stmt);
   Sqlite.Close (DB);
end Example;
