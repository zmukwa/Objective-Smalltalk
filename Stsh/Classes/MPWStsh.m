//
//  MPWStsh.m
//  MPWShellScriptKit
//
//  Created by Marcel Weiher on 26/01/2006.
//  Copyright 2006 Marcel Weiher. All rights reserved


#import "MPWStsh.h"
#import <histedit.h>
#include <readline/readline.h>

#import <ObjectiveSmalltalk/MPWIdentifierExpression.h>
#import "MPWShellCompiler.h"
#import "MPWStScript.h"
#import "MPWObjectMirror.h"
#import "MPWClassMirror.h"
#import "MPWMethodMirror.h"
#import "MPWMessageExpression.h"



@implementation MPWStsh

boolAccessor( readingFile, _setReadingFile )
boolAccessor( echo, setEcho )
idAccessor( _evaluator, _setEvaluator )
objectAccessor(NSString, prompt, _setPrompt)

-evaluator
{
	id eval=[self _evaluator];
	if ( !eval ) {
		eval=self;
	}
	return eval;
}


-(void)setPrompt:(NSString*)newPrompt
{
    [self _setPrompt:newPrompt];
    [newPrompt getCString:cstrPrompt maxLength:100 encoding:NSUTF8StringEncoding];
    cstrPrompt[100]=0;
}

-(void)setEvaluator:newEval
{
	[self _setEvaluator:newEval];
	[newEval bindValue:self toVariableNamed:@"shell"];
}
 

+(void)runCommand:commandName withArgs:args
{
	NSAutoreleasePool* pool=[NSAutoreleasePool new];
	MPWStsh* sh;
	id exprString = [NSString stringWithContentsOfFile:commandName];
	id expr;
	sh=[[[self alloc] initWithArgs:args] autorelease];
//	[sh bindValue:commandName toVariableNamed:@"commandName"];
	[sh setReadingFile:YES];
	[sh executeFromFileName:commandName];
//	expr = [sh compile:exprString];
//	[sh executeShellExpression:expr];
 	[pool release];
}

+(void)runWithArgs:args
{
	NSAutoreleasePool* pool=[NSAutoreleasePool new];
	if ( [args count] >= 1 ) {
		[self runCommand:[args objectAtIndex:0] withArgs:[args subarrayWithRange:NSMakeRange(1,[args count]-1)]];
	} else {
		[[[[self alloc] init] autorelease] runInteractiveLoop];
	}
	[pool release];
}


-(void)setReadingFile:(BOOL)newReadingFile
{
    [self _setReadingFile:newReadingFile];
    [self setEcho:!newReadingFile];
}


-(void)runAppKit
{
	id app=[NSClassFromString(@"NSApplication") sharedApplication];
	[[self async] runInteractiveLoop];
	[[NSRunLoop currentRunLoop] run];
}

-initWithArgs:args evaluator:newEvaluator
{
    if ( self=[super init] ) {
//		NSLog(@"initWithArgs: %@",args);
        [self setPrompt:@"> "];
        Stdout=[MPWByteStream Stdout];
        Stderr=[MPWByteStream Stderr];
		[self setEvaluator:newEvaluator];
		[[self evaluator] bindValue:args toVariableNamed:@"args"];
		[[self evaluator] bindValue:self toVariableNamed:@"shell"];
    }
    return self;
}

-initWithArgs:args
{
	return [self initWithArgs:args evaluator:[[[MPWShellCompiler alloc] init] autorelease]];
}


-init
{
	return [self initWithArgs:[NSArray array]];
}

-(const char*)getCStringPrompt
{
    return cstrPrompt;
}

static const char * promptfn(EditLine *e) {
    MPWStsh* self = nil;
    el_get(e, EL_CLIENTDATA,&self);
    const char *prompt="> ";
    if ( self ) {
        prompt=[self getCStringPrompt];
    }
    return prompt;
}

char *command_generator(char *word, int state) {
    char *options[] = {"I_love_math", "he_love_math", "she_loves_math", "they_love_math", NULL};
    return options[state] ? strdup(options[state]) : NULL;
}

-(NSArray *)messageNamesForObject:value matchingPrefix:(NSString*)prefix
{
    NSMutableArray *messages=[NSMutableArray array];
    MPWObjectMirror *om=[MPWObjectMirror mirrorWithObject:value] ;
    MPWClassMirror *cm=[om classMirror];
    for (MPWMethodMirror *mm in [cm methodMirrors]) {
        if ( !prefix || [prefix length]==0 || [[mm name] hasPrefix:prefix]) {
            [messages addObject:[mm name]];
        }
    }
    return messages;
}

-(void)printCompletions:(NSArray *)names
{
    for ( NSString *name in names) {
        fprintf(stderr, "%s\n",[name UTF8String]);
    }
}

-(NSArray *)variableNamesMatchingPrefix:(NSString*)prefix
{
    NSMutableArray *varNames=[NSMutableArray array];
    NSArray *localVarNames=[[[self _evaluator] localVars] allKeys];
    for (NSString *localName in localVarNames) {
        if ([localName hasPrefix:prefix] ) {
            [varNames addObject:localName];
        }
    }
    return varNames;
}

-(NSString*)commonPrefixInNames:(NSArray*)names
{
    NSString *commonPrefix=[names firstObject];
    for ( NSString *name in names) {
        while ( ![name hasPrefix:commonPrefix] && [commonPrefix length]>0 ) {
            commonPrefix=[commonPrefix substringToIndex:[commonPrefix length]-1];
        }
        if ( [commonPrefix length]==0) {
            break;
        }
    }
    return  commonPrefix;
}

-(void)completeName:(NSString*)currentName withNames:(NSArray*)names inEditLine:(EditLine*)e
{
    NSString *commonPrefix=[self commonPrefixInNames:names];
    if ( [commonPrefix length] >0 ) {
        el_insertstr(e, [[commonPrefix substringFromIndex:[currentName length]] UTF8String]);
    }
    if ([names count]>1) {
        [self printCompletions:names];
    }
}

-(BOOL)doCompletionWithLine:(EditLine*)e character:(char)ch
{
    
    const LineInfo *lineInfo = el_line(e);
    if ( lineInfo) {
        const char *start=lineInfo->buffer;
        const char *end=lineInfo->lastchar;
        NSString *s=[[[NSString alloc] initWithBytes:start length:end-start encoding:NSUTF8StringEncoding] autorelease];

        MPWExpression *expr=nil;
        NSException *exception=nil;
        MPWStCompiler *evaluator=[self _evaluator];
        @try {
            fprintf(stderr, "\n");
            expr=[evaluator compile:s];
            if ( [expr isKindOfClass:[MPWIdentifierExpression class]]) {
                MPWIdentifierExpression *expression=(MPWIdentifierExpression*)expr;
                MPWBinding* binding=[[evaluator localVars] objectForKey:[expression name]];
                id value=[binding value];
                if ( value ) {
                    if ( [s hasSuffix:@" "]) {
                        [self printCompletions:[self messageNamesForObject:value matchingPrefix:nil]];
                    } else {
                        el_insertstr(e," ");
                        return YES;
                    }
                } else {
                    NSString *n=[expression name];
                    [self completeName:n withNames:[self variableNamesMatchingPrefix:n] inEditLine:e];
//                    [self printCompletions:[self variableNamesMatchingPrefix:[expression name]]];
                }
                
                
            } else if ( [expr isKindOfClass:[MPWMessageExpression class]]) {
                MPWMessageExpression *msg=(MPWMessageExpression*)expr;
                id receiver = [[msg receiver] evaluateIn:[self _evaluator]];
                if ( [s hasSuffix:@" "] ) {
                    id value=[msg evaluateIn:[self _evaluator]];
                    NSArray *msgNames=[self messageNamesForObject:value matchingPrefix:nil];
                    [self printCompletions:msgNames];
                } else if ( [receiver respondsToSelector:[msg selector]]) {
                    el_insertstr(e," ");
                    return YES;
                } else {
                    NSString *name=NSStringFromSelector([msg selector]);
                    NSArray *msgNames=[self messageNamesForObject:receiver matchingPrefix:name];
                    [self completeName:name withNames:msgNames inEditLine:e];
                }
            }
        } @catch ( id e){
            exception=e;
        }
    }
#if 0
    // do real completion here
    if ( numTabs++ & 1 == 1) {
        system("ls");
        el_insertstr(e, " ls ");
        el_set(e, EL_REFRESH);
    } else {
        el_insertstr(e, " a word");
    }
    
#endif 
    return NO;
}

static const char completionfun(EditLine *e, char ch) {
    MPWStsh* self = nil;
    el_get(e, EL_CLIENTDATA,&self);
    [self doCompletionWithLine:e character:ch];
    return CC_REDISPLAY;
}

-(void)cd:(NSString*)newDir
{
    [newDir getCString:cwd maxLength:20000];
    cwd[ [newDir length] ] = 0;
    chdir(cwd);
}

-pwd
{
    return [NSString stringWithUTF8String:getwd( NULL )];
}




idAccessor( retval, setRetval )

-(void)executeFromFileName:(NSString*)filename
{
	id script = [MPWStScript scriptWithContentsOfFile:filename];
	[script executeInContext:self];
}

-(BOOL)isAssignmentExpresson:expr
{
	static Class MPWAssignmentExpression=nil;
	static Class MPWStatementList=nil;
	if ( !MPWStatementList ) {
		MPWAssignmentExpression=NSClassFromString(@"MPWAssignmentExpression");
		MPWStatementList=NSClassFromString(@"MPWStatementList");
	}
    return [expr isKindOfClass:MPWAssignmentExpression] 
		|| ([expr isKindOfClass:MPWStatementList] &&
			[[expr statements] count] == 1 && 
			[[[expr statements] lastObject] isKindOfClass:MPWAssignmentExpression]);
}

-(void)runInteractiveLoop
{
	const char* str_result=NULL;
    id result;
    EditLine *el;
    char *lineOfInput;
    History *history_ptr;
    HistEvent event;
    int count=1000;
    history_ptr=history_init();
    el=el_init( "stsh", stdin, stdout, stderr);

    rl_readline_name = "rl_example";
    rl_completion_entry_function = (void*)command_generator;
    rl_initialize();
    rl_parse_and_bind("TAB: menu-complete");

    
    el_set(el, EL_CLIENTDATA, self);
    el_set( el, EL_HIST, history, history_ptr );
    el_set(el, EL_EDITOR, "emacs");
    el_set(el, EL_PROMPT, promptfn);
    el_set(el, EL_ADDFN, "complete", "complete", completionfun);
    el_set(el, EL_BIND, "\t", "complete", NULL);
    
    history(history_ptr, &event, H_SETSIZE, 800);
	[self setEcho:YES];
    while ( (lineOfInput=el_gets(el,&count) ) /*  (lineOfInput=readline("> ")) */) {
        char *save;
 		if ( (lineOfInput[0]!='#') || (lineOfInput[1]=='(') ) {
			id pool=[NSAutoreleasePool new];
			NS_DURING
				id exprString = [NSString stringWithUTF8String:lineOfInput];
            if ( [exprString hasPrefix:@"!"]) {
                if ( [exprString hasPrefix:@"!cd"] ) {
                    NSArray *components = [exprString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    NSString *last=nil;
                    int index=[components count]-1;
                    while (index>0 && [last length]==0) {
                        last=[components objectAtIndex:index];
                        index--;
                    }
                    const char *newDir = [last fileSystemRepresentation];
                   if ( newDir) {
                       int failure = chdir(newDir);
                       if ( failure ) {
                           perror("failed to chdir");
                       }
                    }
                } else {
                    system(lineOfInput+1);
                }
            } else {
				id expr = [[self evaluator] compile:exprString];
                //				NSLog(@"expr: %@",expr);
				BOOL isAssignment = [self isAssignmentExpresson:expr];
				
				if ( [[self evaluator] respondsToSelector:@selector(executeShellExpression:)] )  {
					result = [[self evaluator] executeShellExpression:expr];
				} else {
					result = [[self evaluator] evaluate:expr];
				}
                //				NSLog(@"result: %@/%@",[result class],result);
				if ( result!=nil && [result isNotNil]) {
					[[self evaluator] bindValue:result toVariableNamed:@"last" withScheme:@"var"];
                    if ( [self echo] && !isAssignment ) {
                        //                       str_result = [[result description] cString];
                        //                       str_result = str_result ? str_result : "nil";
						if ( !result ) {
							result=@"nil";
						}
                        fflush(stdout);
//						[[[MPWByteStream Stderr] do] println:[result each]];
//                        NSLog(@"result: %@/%@",[result class],result);
						[[[[self evaluator] bindingForLocalVariableNamed:@"stdout" ]  value] println:[result stringValue]];

                        
                        //                       fprintf(stderr,"%s\n",str_result);
                        fflush(stderr);
                    }
				}
            }
            NS_HANDLER

            NSLog(@"top level exception: %@",localException);
            id combinedStack=[localException combinedStackTrace];
            if ( combinedStack) {
                NSLog(@"%@",combinedStack);
            } else {
                NSLog(@"no stack");
            }
            NS_ENDHANDLER
			[pool release];
		}
            save=malloc( strlen( lineOfInput) +2 );
            strcpy( save, lineOfInput );
            history( history_ptr, &event, H_ENTER, save );
            count=1000;
    }
        fflush(stdout);
        fflush(stderr);
        fprintf(stderr,"\nBye!\n");
}



@end

@implementation NSObject(executeInShell)

-executeInShell:aShell
{
    NSObject* result = [self evaluateIn:aShell];
//	NSLog(@"result of initial eval: %s, may no run process",object_getClassName(result));
	if ( [result isKindOfClass:[NSObject class]] && [result respondsToSelector:@selector(runProcess)] ) {
		result = [result runProcess];
	}
	return result;
}

@end


@implementation MPWIdentifierExpression(executeInShell)

-executeInShell:aShell
{
	id level1result;
//	NSLog(@"%@ executeInShell:",self);
	level1result = [self evaluateIn:aShell];
// 	NSLog(@"level1result: %@ executeInShell:",level1result);
	return [level1result executeInShell:aShell]; 
}

@end


@implementation NSString(shellAdditions)

-initWithSingleUnichar:(int)character
{
	unichar uchar=character;
	return [self initWithCharacters:&uchar length:1];
}

+stringWithSingleUnichar:(int)character
{
	return [[[self alloc] initWithSingleUnichar:character] autorelease];
}

@end
