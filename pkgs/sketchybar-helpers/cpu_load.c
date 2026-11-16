#include "cpu.h"
#include "sketchybar.h"

int main(int argc, char** argv) {
  float update_freq;
  if (argc < 3 || (sscanf(argv[2], "%f", &update_freq) != 1) || update_freq <= 0.0f) {
    printf("Usage: %s \"<event-name>\" \"<event_freq>\"\n", argv[0]);
    exit(1);
  }

  alarm(0);
  struct cpu cpu;
  cpu_init(&cpu);

  char event_message[512];
  snprintf(event_message, sizeof(event_message), "--add event '%s'", argv[1]);
  sketchybar(event_message);

  char trigger_message[512];
  for (;;) {
    cpu_update(&cpu);

    snprintf(trigger_message,
             sizeof(trigger_message),
             "--trigger '%s' user_load='%d' sys_load='%02d' total_load='%02d'",
             argv[1],
             cpu.user_load,
             cpu.sys_load,
             cpu.total_load);

    sketchybar(trigger_message);
    usleep((useconds_t)(update_freq * 1000000));
  }
  return 0;
}
