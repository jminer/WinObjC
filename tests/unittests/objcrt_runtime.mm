//******************************************************************************
//
// Copyright (c) 2015 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#include <TestFramework.h>
#import <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <exception>

//#pragma comment(linker, "/INCLUDE:Foundation.dll!_OBJC_CLASS_NSArray")

@interface TestCaseBaseIvars : NSObject {
    void* ptr;
}
@end
@implementation TestCaseBaseIvars
- (id)init {
    if ((self = [super init]) != nil) {
        ptr = (void*)0x101010;
    }
    return self;
}
- (BOOL)validate {
    return ptr == (void*)0x101010;
}
@end

struct ClassTrailer {
    void* ptr2;
};

@interface TestCaseBase : NSObject
+ (void)setGlobal:(int)g;
+ (int)testcase3:(int)x;
- (int)testcase3:(int)x;
@end

static int _tcbGlobal;
@implementation TestCaseBase
+ (void)setGlobal:(int)g {
    _tcbGlobal = g;
}

+ (int)testcase3:(int)x {
    // Add this definition to fix the compiler warning warning :
    // method definition for 'testcase3:' not found [-Wincomplete-implementation].
    return 0;
}

- (int)testcase3:(int)x {
    // Add this definition to fix the compiler warning warning :
    // method definition for 'testcase3:' not found [-Wincomplete-implementation].
    return 0;
}

@end

int tc3MetaImp(id, SEL, int) {
    return 100;
}

int tc3Imp(id, SEL, int) {
    return 200;
}

#if defined(ANSI_COLOR)
#define SGR_RED "\033[1;31m"
#define SGR_GREEN "\033[1;32m"
#define SGR_RESET "\033[0m"
#else
#define SGR_RED
#define SGR_GREEN
#define SGR_RESET
#endif

bool globalFailure = false;

void perform(const char* what, bool (^block)(), bool flipbit = false) {
    bool b = false;
    const char* xcp = NULL;
    char msgStr[BUFSIZ];
    try {
        b = block();
    } catch (std::exception& e) {
        xcp = _strdup(e.what());
        b = false;
    } catch (...) {
        xcp = "unknown?";
        b = false;
    }
    snprintf(msgStr, sizeof(msgStr), "%s", " - ");
    if (flipbit != b) {
        snprintf(msgStr, sizeof(msgStr), "%s%s", msgStr, (SGR_GREEN "PASSED" SGR_RESET));
    } else {
        globalFailure = true;
        snprintf(msgStr, sizeof(msgStr), "%s%s", msgStr, (SGR_RED "FAILED"));
        if (xcp) {
            snprintf(msgStr, sizeof(msgStr), "%s (" SGR_RESET "%s" SGR_RED ") ", msgStr, xcp);
        }
    }
    snprintf(msgStr, sizeof(msgStr), "%s: %s", msgStr, what);
    LOG_INFO(msgStr);
}

TEST(ObjcrtRunTime, RunTimeTest) {
    [NSArray alloc]; // temp hack, work around Foundation.dll being ignored
    LOG_INFO("OBJCRT runtime subclassing test:");

    perform("PREREQ: NSObject exists",
            ^bool {
                return objc_getClass("NSObject") != Nil;
            });
    perform("can allocate a subclass",
            ^bool {
                Class k = objc_allocateClassPair(objc_getClass("NSObject"), (char*)"TESTCASE1", 0);
                if (!k) {
                    return false;
                }
                return true;
            });
    perform("can allocate and register a subclass",
            ^bool {
                Class k = objc_allocateClassPair(objc_getClass("NSObject"), (char*)"TESTCASE2", 0);
                if (!k) {
                    return false;
                }
                objc_registerClassPair(k);
                return true;
            });
    perform("cannot allocate a class pair for an existing class name",
            ^bool {
                Class k = objc_allocateClassPair(objc_getClass("NSObject"), (char*)"TESTCASE2", 0);
                return k == Nil;
            });
    perform("can not look up a subclass that was only allocated",
            ^bool {
                Class k = Nil;
                try {
                    k = objc_getClass("TESTCASE1");
                } catch (...) {
                }
                return k == Nil;
            });
    perform("can look up a previously registered subclass",
            ^bool {
                Class k = objc_getClass("TESTCASE2");
                return k != Nil;
            });
    perform("can allocate a registered subclass",
            ^bool {
                Class k = objc_getClass("TESTCASE2");
                return k != Nil && [k alloc] != nil;
            });
    perform("can call NSObject methods on a previously registered subclass",
            ^bool {
                Class k = objc_getClass("TESTCASE2");
                if (!k)
                    return false;
                id instance = [[k alloc] init];
                if (!instance)
                    return false;
                return [instance description] != nil;
            });
    perform("can subclass a locally-defined class",
            ^bool {
                Class k = objc_allocateClassPair(objc_getClass("TestCaseBase"), (char*)"TESTCASE3", 0);
                objc_registerClassPair(k);
                return k != Nil;
            });
    perform("can call locally-defined class method and see results",
            ^bool {
                Class k = objc_getClass("TESTCASE3");
                [k setGlobal:10];
                return _tcbGlobal == 10;
            });
    perform("can add a class method to a class",
            ^bool {
                Class k = objc_getClass("TESTCASE3");
                return class_addMethod(object_getClass(k), @selector(testcase3:), (IMP)tc3MetaImp, "i@:");
            });
    perform("can add a instance method to a class",
            ^bool {
                Class k = objc_getClass("TESTCASE3");
                return class_addMethod(k, @selector(testcase3:), (IMP)tc3Imp, "i@:");
            });
    perform("can call a previously-added class method on a class",
            ^bool {
                Class k = objc_getClass("TESTCASE3");
                return [k testcase3:0] == 100;
            });
    perform("can call a previously-added instance method on a class",
            ^bool {
                Class k = objc_getClass("TESTCASE3");
                return [[k alloc] testcase3:0] == 200;
            });

    perform("can NOT call a method added on a subclass on its superclass",
            ^bool {
                [TestCaseBase testcase3:10];
                [[TestCaseBase alloc] testcase3:10];
                return false;
            },
            true);

    perform("can subclass a runtime subclass",
            ^bool {
                Class k = objc_allocateClassPair(objc_getClass("TESTCASE3"), (char*)"TESTCASE4", 0);
                if (!k)
                    return false;
                objc_registerClassPair(k);
                return true;
            });
    perform("can call a previously-added class method on that class",
            ^bool {
                Class k = objc_getClass("TESTCASE4");
                return [k testcase3:0] == 100;
            });
    perform("can call a previously-added instance method on that class",
            ^bool {
                Class k = objc_getClass("TESTCASE4");
                return [[k alloc] testcase3:0] == 200;
            });

    perform("can subclass with indexed ivars",
            ^bool {
                Class k = objc_allocateClassPair([TestCaseBaseIvars class], (char*)"TESTCASE5", sizeof(struct ClassTrailer));
                if (!k)
                    return false;
                objc_registerClassPair(k);
                return true;
            });
    perform("can access indexed ivars",
            ^bool {
                Class k = objc_getClass("TESTCASE5");
                void* iiv = object_getIndexedIvars((id)k);
                if (!iiv)
                    return false;
                if (iiv == k)
                    return false;
                return true;
            });
    perform("indexed ivars do not damage instance",
            ^bool {
                Class k = objc_getClass("TESTCASE5");
                TestCaseBaseIvars* instance = objc_allocateObject(k, sizeof(ClassTrailer));
                instance = [instance init];

                ClassTrailer* iiv = (ClassTrailer*)object_getIndexedIvars((id)instance);
                if (!iiv)
                    return false;
                if ((void*)iiv == instance)
                    return false;

                iiv->ptr2 = (void*)0x202020;
                return [instance validate];
            });
    ASSERT_FALSE(globalFailure);
}

@interface ClassWithALotOfProperties : NSObject
@property (assign) int a;
@property (assign) int b;
@property (assign) int c;
@property (assign) int d;
@property (assign) int e;
@property (assign) int f;
@property (assign) int g;
@property (assign) int h;
@property (assign) int i;
@property (assign) int j;
@property (assign) int k;
@property (assign) int l;
@property (assign) int m;
@property (assign) int n;
@property (assign) int o;
@property (assign) int p;
@property (assign) int q;
@end
@implementation ClassWithALotOfProperties
@end

TEST(Objcrt, CopyPropertyList) {
    objc_property_t* properties = nullptr;
    unsigned count = 0;
    properties = class_copyPropertyList([ClassWithALotOfProperties class], &count);

    ASSERT_EQ(17, count);

    EXPECT_STREQ("q", property_getName(properties[16]));
    EXPECT_STREQ("p", property_getName(properties[15]));

    free(properties);
}

TEST(Objcrt, ClassGetProperty) {
    objc_property_t a = class_getProperty([ClassWithALotOfProperties class], "a");
    EXPECT_NE(nullptr, a);

    objc_property_t badLookup1 = class_getProperty([ClassWithALotOfProperties class], NULL);
    EXPECT_EQ(nullptr, badLookup1);

    objc_property_t badLookup2 = class_getProperty(Nil, "a");
    EXPECT_EQ(nullptr, badLookup2);
}
