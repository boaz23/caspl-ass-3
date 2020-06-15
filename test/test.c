#include <stdlib.h>
#include <stdio.h>
#include <string.h>

typedef struct drone {
    double x;
    double y;
    double speed;
    double angle;
    int score;
    int is_active;
} drone;

extern int DebugMode;
extern int N;
extern int R;
extern int K;
extern double d;
extern short seed;

typedef drone* pdrone;
extern pdrone *DronesArr;
extern short LSFR;
extern double TargetPosition_x;
extern double TargetPosition_y;

typedef struct COR {
    void (*func)(); // func pointer
    int flags;
    void *spp; // stack pointer
    void *bpp; // base pointer
    void *hsp; // pointer for lowest stack address
} COR;

extern COR **CORS;
extern int CoId_Scheduler;
extern int CoId_Printer;
extern int CoId_Target;

extern int main_1(int argc, char *argv[]);
extern void (*free_game_resources)(void);
extern void (*drone_co_func)();

void print_info() {
    if (DronesArr) {
        for (int i = 0; i < 5; ++i) {
            printf("%p ", &DronesArr[i]);
        }
        printf("\n");
        for (int i = 0; i < 5; ++i) {
            printf("%p ", DronesArr[i]);
        }
        printf("\n");
    }
}
int main(int argc, char *argv[]) {
    main_1(argc, argv);
    print_info();
    free_game_resources();
    return 0;
}