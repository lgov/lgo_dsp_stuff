# Makefile for the load_ratings workspace

CC=gcc
CFLAGS=-g

LIB_PATHS=-L/opt/local/lib -L/usr/local/lib
INC_PATHS=-I/opt/local/include

LIBS=-lsqlite3

OBJS=$(addprefix $(OBJDIR)/, load_ratings.o store_sqlite3.o)
OBJDIR=build

load_ratings: $(OBJS)
		$(CC) -o load_ratings $(LIB_PATHS) $(LIBS) $(OBJS)

$(OBJDIR)/%.o : %.c
		$(CC) $(CFLAGS) $(INC_PATHS) -o $(OBJDIR)/$*.o -c $<

clean:
		rm -f load_ratings $(OBJDIR)/*.o $(OBJDIR)/tests
