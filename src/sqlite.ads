--
--  Copyright 2023 (C) Jeremy Grosser
--
--  SPDX-License-Identifier: BSD-3-Clause
--
with Interfaces.C;
with Interfaces;
with System.Storage_Elements;

package Sqlite
   with Preelaborate
is

   Database_Error : exception;

   type Connection_Data is private;
   type Connection is access all Connection_Data;

   type Statement_Data is private;
   type Statement is access all Statement_Data;

   type Result_Code is
      (SQLITE_OK,
       SQLITE_ERROR,
       SQLITE_INTERNAL,
       SQLITE_PERM,
       SQLITE_ABORT,
       SQLITE_BUSY,
       SQLITE_LOCKED,
       SQLITE_NOMEM,
       SQLITE_READONLY,
       SQLITE_INTERRUPT,
       SQLITE_IOERR,
       SQLITE_CORRUPT,
       SQLITE_NOTFOUND,
       SQLITE_FULL,
       SQLITE_CANTOPEN,
       SQLITE_PROTOCOL,
       SQLITE_EMPTY,
       SQLITE_SCHEMA,
       SQLITE_TOOBIG,
       SQLITE_CONSTRAINT,
       SQLITE_MISMATCH,
       SQLITE_MISUSE,
       SQLITE_NOLFS,
       SQLITE_AUTH,
       SQLITE_FORMAT,
       SQLITE_RANGE,
       SQLITE_NOTADB,
       SQLITE_NOTICE,
       SQLITE_WARNING,
       SQLITE_ROW,
       SQLITE_DONE)
       with Size => 32;

   for Result_Code use
      (SQLITE_OK           => 0,
       SQLITE_ERROR        => 1,
       SQLITE_INTERNAL     => 2,
       SQLITE_PERM         => 3,
       SQLITE_ABORT        => 4,
       SQLITE_BUSY         => 5,
       SQLITE_LOCKED       => 6,
       SQLITE_NOMEM        => 7,
       SQLITE_READONLY     => 8,
       SQLITE_INTERRUPT    => 9,
       SQLITE_IOERR        => 10,
       SQLITE_CORRUPT      => 11,
       SQLITE_NOTFOUND     => 12,
       SQLITE_FULL         => 13,
       SQLITE_CANTOPEN     => 14,
       SQLITE_PROTOCOL     => 15,
       SQLITE_EMPTY        => 16,
       SQLITE_SCHEMA       => 17,
       SQLITE_TOOBIG       => 18,
       SQLITE_CONSTRAINT   => 19,
       SQLITE_MISMATCH     => 20,
       SQLITE_MISUSE       => 21,
       SQLITE_NOLFS        => 22,
       SQLITE_AUTH         => 23,
       SQLITE_FORMAT       => 24,
       SQLITE_RANGE        => 25,
       SQLITE_NOTADB       => 26,
       SQLITE_NOTICE       => 27,
       SQLITE_WARNING      => 28,
       SQLITE_ROW          => 100,
       SQLITE_DONE         => 101);

   type Open_Flags is record
      READONLY       : Boolean;
      READWRITE      : Boolean;
      CREATE         : Boolean;
      DELETEONCLOSE  : Boolean;
      EXCLUSIVE      : Boolean;
      AUTOPROXY      : Boolean;
      URI            : Boolean;
      MEMORY         : Boolean;
      MAIN_DB        : Boolean;
      TEMP_DB        : Boolean;
      TRANSIENT_DB   : Boolean;
      MAIN_JOURNAL   : Boolean;
      TEMP_JOURNAL   : Boolean;
      SUBJOURNAL     : Boolean;
      SUPER_JOURNAL  : Boolean;
      NOMUTEX        : Boolean;
      FULLMUTEX      : Boolean;
      SHAREDCACHE    : Boolean;
      PRIVATECACHE   : Boolean;
      WAL            : Boolean;
      NOFOLLOW       : Boolean;
   end record
      with Size => 32;

   type Value_Type is
      (SQLITE_INTEGER,
       SQLITE_FLOAT,
       SQLITE_TEXT,
       SQLITE_BLOB,
       SQLITE_NULL)
   with Size => Interfaces.C.int'Size;

   for Value_Type use
      (SQLITE_INTEGER   => 1,
       SQLITE_FLOAT     => 2,
       SQLITE_TEXT      => 3,
       SQLITE_BLOB      => 4,
       SQLITE_NULL      => 5);

   procedure Initialize;

   function Open
      (Filename : String;
       Flags    : Open_Flags := (others => False))
       return Connection;

   function Is_Open
      (Conn : Connection)
      return Boolean;

   function Prepare
      (Conn : Connection;
       SQL  : String)
       return Statement;

   function Is_Prepared
      (Stmt : Statement)
      return Boolean;

   procedure Bind_Text
      (Conn  : Connection;
       Stmt  : Statement;
       Param : Natural;
       Text  : String);

   function Step
      (Conn : Connection;
       Stmt : Statement)
      return Result_Code;

   function Column_Count
      (Stmt : Statement)
      return Natural;

   function Column_Type
      (Stmt    : Statement;
       Column  : Natural)
       return Value_Type;

   function Is_Null
      (Stmt   : Statement;
       Column : Natural)
       return Boolean;

   function Length
      (Stmt   : Statement;
       Column : Natural)
       return Natural;

   procedure To_String
      (Stmt    : Statement;
       Column  : Natural;
       Item    : out String)
   with Pre => Column_Type (Stmt, Column) = SQLITE_TEXT and then
               Item'Length = Length (Stmt, Column);

   function To_String
      (Stmt    : Statement;
       Column  : Natural)
       return String;

   subtype Blob is System.Storage_Elements.Storage_Array;
   --  Assumes Storage_Element'Size = 8, which is true on all platforms GNAT
   --  supports.

   procedure To_Blob
      (Stmt    : Statement;
       Column  : Natural;
       Item    : out Blob)
   with Pre => Column_Type (Stmt, Column) = SQLITE_BLOB and then
               Item'Length = Length (Stmt, Column);

   function To_Blob
      (Stmt    : Statement;
       Column  : Natural)
       return Blob;

   function To_Long_Integer
      (Stmt    : Statement;
       Column  : Natural)
       return Long_Integer
   with Pre => Column_Type (Stmt, Column) = SQLITE_INTEGER;

   function To_Integer
      (Stmt    : Statement;
       Column  : Natural)
       return Integer
   with Pre => Column_Type (Stmt, Column) = SQLITE_INTEGER;

   function To_Long_Float
      (Stmt    : Statement;
       Column  : Natural)
       return Long_Float
   with Pre => Column_Type (Stmt, Column) = SQLITE_FLOAT;

   function To_Float
      (Stmt    : Statement;
       Column  : Natural)
       return Float
   with Pre => Column_Type (Stmt, Column) = SQLITE_FLOAT;

   procedure Reset
      (Conn : Connection;
       Stmt : Statement);

   procedure Finalize
      (Conn : Connection;
       Stmt : in out Statement);

   procedure Exec
      (Conn : Connection;
       SQL  : String);

   procedure Close
      (Conn : in out Connection);

private

   type Connection_Data is null record;
   type Statement_Data is null record;

   for Open_Flags use record
      READONLY       at 0 range 0 .. 0;
      READWRITE      at 0 range 1 .. 1;
      CREATE         at 0 range 2 .. 2;
      DELETEONCLOSE  at 0 range 3 .. 3;
      EXCLUSIVE      at 0 range 4 .. 4;
      AUTOPROXY      at 0 range 5 .. 5;
      URI            at 0 range 6 .. 6;
      MEMORY         at 0 range 7 .. 7;
      MAIN_DB        at 0 range 8 .. 8;
      TEMP_DB        at 0 range 9 .. 9;
      TRANSIENT_DB   at 0 range 10 .. 10;
      MAIN_JOURNAL   at 0 range 11 .. 11;
      TEMP_JOURNAL   at 0 range 12 .. 12;
      SUBJOURNAL     at 0 range 13 .. 13;
      SUPER_JOURNAL  at 0 range 14 .. 14;
      NOMUTEX        at 0 range 15 .. 15;
      FULLMUTEX      at 0 range 16 .. 16;
      SHAREDCACHE    at 0 range 17 .. 17;
      PRIVATECACHE   at 0 range 18 .. 18;
      WAL            at 0 range 19 .. 19;
      NOFOLLOW       at 0 range 20 .. 20;
   end record;

end Sqlite;
