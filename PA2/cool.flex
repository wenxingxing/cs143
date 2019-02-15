%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>
#include <string>

#define yylval cool_yylval
#define yylex  cool_yylex
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */
extern FILE *fin; /* we read from this file */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");
char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

static int comment_layer = 0;
extern int curr_lineno;
extern int verbose_flag;
extern YYSTYPE cool_yylval;
%}
%Start          COMMENTS
%Start          INLINE_COMMENTS
%Start          STRING
%%
 /* ========
  * Comments
  * ========
  */

 /* Nested comments */

<INITIAL,COMMENTS,INLINE_COMMENTS>"(*" {
  comment_layer++;
  BEGIN COMMENTS;
}

<COMMENTS>[^\n(*]* { }

<COMMENTS>[()*] { }


<COMMENTS>"*)" {
  --comment_layer;
  if(comment_layer == 0){
    BEGIN 0;
  }
}

<COMMENTS><<EOF>> {
    yylval.error_msg = "EOF in comment";
    BEGIN 0;
    return ERROR;
}

"*)" {
    yylval.error_msg = "Unmatched *)";
    return ERROR;
}

 /* Inline comments */
 <INITIAL>"--" {
   BEGIN INLINE_COMMENTS;
 }

 <INLINE_COMMENTS>[^\n]* { }

 <INLINE_COMMENTS>"\n" {
   curr_lineno++;
   BEGIN 0;
 }

 /* =========
  * STR_CONST
  * =========
  * String constants (C syntax)
  * Escape sequence \c is accepted for all characters c. Except for
  * \n \t \b \f, the result is c.
  */

<INITIAL>\" {
  BEGIN STRING;
  yymore();
}

 /* Cannot read '\\' '\"' '\n' */
<STRING>[^\\\"\n]* { yymore(); }

 /* normal escape characters, not \n */
<STRING>\\[^\n] { yymore(); }

<STRING>\\\n {
  curr_lineno++;
  yymore();
}

 /* meet EOF in the middle of a string, error */
<STRING><<EOF>> {
    yylval.error_msg = "EOF in string constant";
    BEGIN 0;
    yyrestart(yyin);
    return ERROR;
}

 /* meet a '\n' in the middle of a string without a '\\', error */
<STRING>\n {
    yylval.error_msg = "Unterminated string constant";
    BEGIN 0;
    curr_lineno++;
    return ERROR;
}

 /* meet a "\\0" ??? */
<STRING>\\0 {
    yylval.error_msg = "Unterminated string constant";
    BEGIN 0;
    return ERROR;
}

 /* string ends, we need to deal with some escape characters */
<STRING>\" {
    std::string input(yytext, yyleng);

    // remove the '\"'s on both sizes.
    input = input.substr(1, input.length() - 2);

    std::string output = "";
    std::string::size_type pos;

    if (input.find_first_of('\0') != std::string::npos) {
        yylval.error_msg = "String contains null character";
        BEGIN 0;
        return ERROR;
    }

    while ((pos = input.find_first_of("\\")) != std::string::npos) {
        output += input.substr(0, pos);

        switch (input[pos + 1]) {
        case 'b':
            output += "\b";
            break;
        case 't':
            output += "\t";
            break;
        case 'n':
            output += "\n";
            break;
        case 'f':
            output += "\f";
            break;
        default:
            output += input[pos + 1];
            break;
        }

        input = input.substr(pos + 2, input.length() - 2);
    }

    output += input;

    if (output.length() > 1024) {
        yylval.error_msg = "String constant too long";
        BEGIN 0;
        return ERROR;
    }

    cool_yylval.symbol = stringtable.add_string((char*)output.c_str());
    BEGIN 0;
    return STR_CONST;
}

 /* ========
  * Keywords
  * ========
  */

(?i:class) { return CLASS; }
(?i:else) { return ELSE; }
(?i:fi) { return FI; }
(?i:if) { return IF; }
(?i:in) { return IN; }
(?i:inherits) { return INHERITS; }
(?i:let) { return LET; }
(?i:loop) { return LOOP; }
(?i:pool) { return POOL; }
(?i:then) { return THEN; }
(?i:while) { return WHILE; }
(?i:case) { return CASE; }
(?i:esac) { return ESAC; }
(?i:of) { return OF; }
(?i:new) { return NEW; }
(?i:isvoid) { return ISVOID; }
(?i:not) { return NOT; }

 /* INT_CONST */
[0-9]+ {
    cool_yylval.symbol = inttable.add_string(yytext);
    return INT_CONST;
}

 /* BOOL_CONST */
t(?i:rue) {
    cool_yylval.boolean = 1;
    return BOOL_CONST;
}

f(?i:alse) {
    cool_yylval.boolean = 0;
    return BOOL_CONST;
}

 /* White Space */
[ \f\r\t\v]+ { }

 /* TYPEID */
[A-Z][A-Za-z0-9_]* {
    cool_yylval.symbol = idtable.add_string(yytext);
    return TYPEID;
}

 /* OBJECTID */
[a-z][A-Za-z0-9_]* {
    cool_yylval.symbol = idtable.add_string(yytext);
    return OBJECTID;
}

 /* To treat lines. */
"\n" {
    curr_lineno++;
}

 /* =========
  * operators
  * =========
  */

 /* ASSIGN */
"<-" { return ASSIGN; }

 /* LE */
"<=" { return LE; }

 /* DARROW */
"=>" { return DARROW; }
"+" { return int('+'); }
"-" { return int('-'); }
"*" { return int('*'); }
"/" { return int('/'); }
"<" { return int('<'); }
"=" { return int('='); }
"." { return int('.'); }
";" { return int(';'); }
"~" { return int('~'); }
"{" { return int('{'); }
"}" { return int('}'); }
"(" { return int('('); }
")" { return int(')'); }
":" { return int(':'); }
"@" { return int('@'); }
"," { return int(','); }

 /* =====
  * error
  * =====
  */

[^\n] {
    yylval.error_msg = yytext;
    return ERROR;
}

%%