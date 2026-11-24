--
--  Copyright 2023 (C) Jeremy Grosser
--
--  SPDX-License-Identifier: BSD-3-Clause
--
with Ada.Unchecked_Conversion;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with Interfaces.C; use Interfaces.C;
with System;

package body Sqlite is

   procedure Check
      (Status : Result_Code;
       DB     : Connection;
       Msg    : String)
   is
      function Error_Message
         (DB : not null Connection)
         return chars_ptr
      with Import, Convention => C, External_Name => "sqlite3_errmsg";
   begin
      if Status /= SQLITE_OK then
         if DB /= null then
            raise Database_Error with "Database " & Status'Image & " " & Msg & ": " & Value (Error_Message (DB));
         else
            raise Database_Error with "Database " & Status'Image & " " & Msg;
         end if;
      end if;
   end Check;

   procedure Initialize is
      function C_Initialize
         return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_initialize";
   begin
      Check (C_Initialize, null, "Initialize");
   end Initialize;

   function Open
      (Filename : String;
       Flags    : Open_Flags := (others => False))
       return Connection
   is
      function To_Int is new Ada.Unchecked_Conversion (Open_Flags, int);
      function C_Open
         (Filename : chars_ptr;
          DB       : out Connection;
          Flags    : int;
          VFS      : System.Address := System.Null_Address)
          return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_open_v2";

      Name : chars_ptr := New_String (Filename);
      Conn : Connection;
   begin
      Check (C_Open (Name, Conn, To_Int (Flags)), Conn, "Open");
      Free (Name);
      return Conn;
   end Open;

   function Is_Open
      (Conn : Connection)
      return Boolean
   is (Conn /= null);

   function Prepare
      (Conn : Connection;
       SQL  : String)
       return Statement
   is
      function C_Prepare
         (DB      : not null Connection;
          SQL     : String;
          Length  : int;
          Stmt    : out Statement;
          Tail    : System.Address)
          return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_prepare_v2";

      Stmt : Statement;
   begin
      Check (C_Prepare (Conn, SQL, int (SQL'Length), Stmt, System.Null_Address), Conn, "Prepare");
      if Stmt = null then
         raise Database_Error with "sqlite3_prepare_v2 returned null stmt";
      end if;
      return Stmt;
   end Prepare;

   function Is_Prepared
      (Stmt : Statement)
      return Boolean
   is (Stmt /= null);

   procedure Bind_Text
      (Conn  : Connection;
       Stmt  : Statement;
       Param : Natural;
       Text  : String)
   is
      SQLITE_TRANSIENT : constant System.Address :=
         System.Storage_Elements.To_Address
            (System.Storage_Elements.Integer_Address'Last);
      --  (void*)-1 is dumb.

      function C_Bind_Text
         (Stmt       : not null Statement;
          Param      : int;
          Text       : String;
          Length     : int;
          Destructor : System.Address)
          return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_bind_text";
   begin
      Check (C_Bind_Text (Stmt, int (Param), Text & ASCII.NUL, Text'Length, SQLITE_TRANSIENT), Conn, "Bind_Text");
   end Bind_Text;

   procedure Bind_Integer
      (Conn    : Connection;
       Stmt    : Statement;
       Param   : Natural;
       Value   : Integer)
   is
      function C_Bind_Int
         (Stmt : not null Statement;
          Param : int;
          Value : int)
          return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_bind_int";
   begin
      Check (C_Bind_Int (Stmt, int (Param), int (Value)), Conn, "Bind_Integer");
   end Bind_Integer;

   procedure Bind_Integer_64
      (Conn    : Connection;
       Stmt    : Statement;
       Param   : Natural;
       Value   : Interfaces.Integer_64)
   is
      function C_Bind_Int64
         (Stmt : not null Statement;
          Param : int;
          Value : Interfaces.Integer_64)
          return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_bind_int64";
   begin
      Check (C_Bind_Int64 (Stmt, int (Param), Value), Conn, "Bind_Integer_64");
   end Bind_Integer_64;

   procedure Bind_Long_Float
      (Conn    : Connection;
       Stmt    : Statement;
       Param   : Natural;
       Value   : Long_Float)
   is
      function C_Bind_Double
         (Stmt  : not null Statement;
          Param : int;
          Value : double)
          return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_bind_double";
   begin
      Check (C_Bind_Double (Stmt, int (Param), double (Value)), Conn, "Bind_Long_Float");
   end Bind_Long_Float;

   procedure Bind_Null
      (Conn    : Connection;
       Stmt    : Statement;
       Param   : Natural)
   is
      function C_Bind_Null
         (Stmt  : not null Statement;
          Param : int)
          return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_bind_null";
   begin
      Check (C_Bind_Null (Stmt, int (Param)), Conn, "Bind_Null");
   end Bind_Null;

   procedure Bind_Blob
      (Conn    : Connection;
       Stmt    : Statement;
       Param   : Natural;
       Value   : Blob)
   is
      SQLITE_TRANSIENT : constant System.Address :=
         System.Storage_Elements.To_Address
            (System.Storage_Elements.Integer_Address'Last);

      function C_Bind_Blob64
         (Stmt       : not null Statement;
          Param      : int;
          Data       : System.Address;
          Length     : Interfaces.Unsigned_64;
          Destructor : System.Address)
          return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_bind_blob64";

      function C_Bind_Zeroblob
         (Stmt   : not null Statement;
          Param  : int;
          Length : int)
          return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_bind_zeroblob";
   begin
      --  sqlite3_bind_blob binds NULL when given a null pointer, and an
      --  empty array has no address to give it
      if Value'Length = 0 then
         Check (C_Bind_Zeroblob (Stmt, int (Param), 0), Conn, "Bind_Blob");
      else
         Check (C_Bind_Blob64 (Stmt, int (Param), Value'Address, Interfaces.Unsigned_64 (Value'Length),
                               SQLITE_TRANSIENT), Conn, "Bind_Blob");
      end if;
   end Bind_Blob;

   function Step
      (Conn : Connection;
       Stmt : Statement)
      return Result_Code
   is
      function C_Step
         (Stmt : not null Statement)
         return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_step";

      RC : Result_Code;
   begin
      RC := C_Step (Stmt);
      if RC in SQLITE_ERROR .. SQLITE_WARNING then
         Check (RC, Conn, "Step");
      end if;
      return RC;
   end Step;

   function Column_Count
      (Stmt : Statement)
      return Natural
   is
      function C_Column_Count
         (Stmt : not null Statement)
         return int
      with Import, Convention => C, External_Name => "sqlite3_column_count";
   begin
      return Natural (C_Column_Count (Stmt));
   end Column_Count;

   function Column_Type
      (Stmt   : Statement;
       Column : Natural)
       return Value_Type
   is
      function C_Column_Type
         (Stmt : not null Statement;
          Col  : int)
          return Value_Type
      with Import, Convention => C, External_Name => "sqlite3_column_type";
   begin
      return C_Column_Type (Stmt, int (Column));
   end Column_Type;

   function Is_Null
      (Stmt   : Statement;
       Column : Natural)
       return Boolean
   is (Column_Type (Stmt, Column) = SQLITE_NULL);

   function Length
      (Stmt   : Statement;
       Column : Natural)
       return Natural
   is
      function C_Column_Bytes
         (Stmt : not null Statement;
          Col  : int)
          return int
      with Import, Convention => C, External_Name => "sqlite3_column_bytes";
   begin
      return Natural (C_Column_Bytes (Stmt, int (Column)));
   end Length;

   procedure To_String
      (Stmt    : Statement;
       Column  : Natural;
       Item    : out String)
   is
      function C_Column_Text
         (Stmt : not null Statement;
          Col  : int)
          return System.Address
      with Import, Convention => C, External_Name => "sqlite3_column_text";
   begin
      --  Copied by length, as To_Blob is: Interfaces.C.Strings.Value stops at
      --  a NUL in the text, and refuses a length of 0 (an empty string)
      if Item'Length > 0 then
         declare
            Text : String (Item'Range)
               with Import, Address => C_Column_Text (Stmt, int (Column));
         begin
            Item := Text;
         end;
      end if;
   end To_String;

   function To_String
      (Stmt   : Statement;
       Column : Natural)
       return String
   is
      Str : String (1 .. Length (Stmt, Column));
   begin
      To_String (Stmt, Column, Str);
      return Str;
   end To_String;

   procedure To_Blob
      (Stmt    : Statement;
       Column  : Natural;
       Item    : out Blob)
   is
      use System.Storage_Elements;

      function C_Column_Blob
         (Stmt : not null Statement;
          Col  : int)
          return System.Address
      with Import, Convention => C, External_Name => "sqlite3_column_blob";

      Bytes : Blob (1 .. Item'Length)
         with Address => C_Column_Blob (Stmt, int (Column));
   begin
      Item := Bytes;
   end To_Blob;

   function To_Blob
      (Stmt    : Statement;
       Column  : Natural)
       return Blob
   is
      use System.Storage_Elements;
      Item : Blob (1 .. Storage_Offset (Length (Stmt, Column)));
   begin
      To_Blob (Stmt, Column, Item);
      return Item;
   end To_Blob;

   function To_Long_Integer
      (Stmt   : Statement;
       Column : Natural)
       return Long_Integer
   is
      function C_Column_Int64
         (Stmt : not null Statement;
          Col  : int)
          return Interfaces.Integer_64
      with Import, Convention => C, External_Name => "sqlite3_column_int64";
   begin
      return Long_Integer (C_Column_Int64 (Stmt, int (Column)));
   end To_Long_Integer;

   function To_Integer
      (Stmt   : Statement;
       Column : Natural)
       return Integer
   is
      function C_Column_Int
         (Stmt : not null Statement;
          Col  : int)
          return int
      with Import, Convention => C, External_Name => "sqlite3_column_int";
   begin
      return Integer (C_Column_Int (Stmt, int (Column)));
   end To_Integer;

   function C_Column_Double
      (Stmt : not null Statement;
       Col  : int)
       return double
   with Import, Convention => C, External_Name => "sqlite3_column_double";

   function To_Long_Float
      (Stmt   : Statement;
       Column : Natural)
       return Long_Float
   is (Long_Float (C_Column_Double (Stmt, int (Column))));

   function To_Float
      (Stmt   : Statement;
       Column : Natural)
       return Float
   is (Float (C_Column_Double (Stmt, int (Column))));

   procedure Reset
      (Conn : Connection;
       Stmt : Statement)
   is
      function C_Reset
         (Stmt : not null Statement)
         return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_reset";
   begin
      Check (C_Reset (Stmt), Conn, "Reset");
   end Reset;

   function Changes
      (Conn : Connection)
      return Natural
   is
      function C_Changes
         (DB : not null Connection)
         return int
      with Import, Convention => C, External_Name => "sqlite3_changes";
   begin
      return Natural (C_Changes (Conn));
   end Changes;

   function Last_Insert_Row_Id
      (Conn : Connection)
      return Interfaces.Integer_64
   is
      function C_Last_Insert_Rowid
         (DB : not null Connection)
         return Interfaces.Integer_64
      with Import, Convention => C, External_Name => "sqlite3_last_insert_rowid";
   begin
      return C_Last_Insert_Rowid (Conn);
   end Last_Insert_Row_Id;

   procedure Finalize
      (Conn : Connection;
       Stmt : in out Statement)
   is
      function C_Finalize
         (Stmt : not null Statement)
         return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_finalize";
   begin
      Check (C_Finalize (Stmt), Conn, "Finalize");
      Stmt := null;
   end Finalize;

   procedure Exec
      (Conn : Connection;
       SQL  : String)
   is
      function C_Exec
         (DB         : not null Connection;
          SQL        : String;
          Callback   : System.Address := System.Null_Address;
          Arg        : System.Address := System.Null_Address;
          Errmsg     : System.Address := System.Null_Address)
          return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_exec";
   begin
      Check (C_Exec (Conn, SQL & ASCII.NUL), Conn, "Exec");
   end Exec;

   procedure Close
      (Conn : in out Connection)
   is
      function C_Close
         (DB : not null Connection)
         return Result_Code
      with Import, Convention => C, External_Name => "sqlite3_close";
   begin
      Check (C_Close (Conn), Conn, "Close");
      Conn := null;
   end Close;

end Sqlite;
