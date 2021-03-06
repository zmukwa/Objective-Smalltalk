//
//  MPWShellPrinter.m
//  ObjectiveSmalltalk
//
//  Created by Marcel Weiher on 5/22/14.
//
//

#import "MPWShellPrinter.h"
#import "MPWDirectoryBinding.h"
#import <histedit.h>
#include <readline/readline.h>

@interface NSObject(shellPrinting)

-(void)writeOnShellPrinter:(MPWShellPrinter*)aPrinter;


@end


@implementation MPWShellPrinter

-(SEL)streamWriterMessage
{
    return @selector(writeOnShellPrinter:);
}


-(int)terminalWidth
{
    struct winsize w;
    ioctl(0, TIOCGWINSZ, &w);
    
    return w.ws_col;
}



-(void)printNames:(NSArray*)names limit:(int)completionLimit
{
    int numEntries=MIN(completionLimit,(int)[names count]);
    int numColumns=1;
    int terminalWidth=[self terminalWidth];
    int minSpacing=2;
    int maxWidth=0;
    int columnWidth=0;
    int numRows=0;
    for  (int i=0; i<numEntries;i++ ){
        if ( [names[i] length] > maxWidth ) {
            maxWidth=(int)[names[i] length];
        }
    }
    numColumns=terminalWidth / (maxWidth+minSpacing);
    numColumns=MAX(numColumns,1);
    columnWidth=terminalWidth/(numColumns);
    numRows=(numEntries+numColumns-1)/numColumns;
    
    
    for ( int i=0; i<numRows;i++ ){
        for (int j=0;j<numColumns;j++) {
            int theItemIndex=i*numColumns + j;
            
            if ( theItemIndex < [names count]) {
                NSString *theItem=names[theItemIndex];
                [self printFormat:@"%.*s",columnWidth,[theItem UTF8String]];
                if (j<numColumns-1) {
                    int columnPad =columnWidth-(int)[theItem length];
                    columnPad=MIN(MAX(columnPad,0),columnWidth);
                    for (int sp=0;sp<columnPad;sp++) {
                        [self appendBytes:" " length:1];
                    }
                }
            }
        }
        if ( i<numRows-1) {
            [self println:@""];
        }
    }
}

-(void)writeFancyFileEntry:(MPWFileBinding*)binding
{
    NSFileManager *fm=[NSFileManager defaultManager];
    NSString *path=(NSString*)[binding path];
    NSString *name=[path lastPathComponent];
    if ( ![name hasPrefix:@"."]) {
        NSDictionary *attributes=[fm attributesOfItemAtPath:path error:nil];
        NSNumber *size=[attributes objectForKey:NSFileSize];
        NSString *formattedSize=[NSByteCountFormatter stringFromByteCount:[size intValue] countStyle:NSByteCountFormatterCountStyleBinary /* NSByteCountFormatterCountStyleFile */];
        int numSpaces=10-(int)[formattedSize length];
        numSpaces=MAX(0,numSpaces);
        NSString *spaces=[@"               " substringToIndex:numSpaces];
        [self printFormat:@"%@%@  %@%c\n",spaces,formattedSize,name,[binding isDirectory] ? '/':' '];
    }
}

-(void)writeDirectory:(MPWDirectoryBinding*)aBinding
{
    NSMutableArray *names=[NSMutableArray array];
    for ( MPWFileBinding *binding in [aBinding contents]) {
        NSString *name=[(NSString*)[binding path] lastPathComponent];
        if ( ![name hasPrefix:@"."]) {
            if ( [binding isDirectory]) {
                name=[name stringByAppendingString:@"/"];
            }
            [names addObject:name];
        }
    }
    [self printNames:names limit:1000];
}

-(void)writeFancyDirectory:(MPWDirectoryBinding*)aBinding
{
    for ( MPWFileBinding *binding in [aBinding contents]) {
        [self writeFancyFileEntry:binding];
    }
}

@end

@implementation NSObject(shellPrinting)

-(void)writeOnShellPrinter:(MPWShellPrinter*)aPrinter
{
    [self writeOnPropertyList:aPrinter];
}

@end
