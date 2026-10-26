// One installable QA build for the physical phone, so each round needs a
// single install prompt. Launch 1 runs everything including the CRUD create
// pass and the offline check; launch 2 (same install) runs the read-only
// checks again and the CRUD restart/cleanup pass.
import 'bug_checks_test.dart' as bug_checks;
import 'crud_live_test.dart' as crud;
import 'forms_tour_test.dart' as forms;
import 'offline_recovery_test.dart' as offline;
import 'readonly_tour_test.dart' as tour;
import 'sandbox_probe_test.dart' as probe;

void main() {
  probe.main();
  tour.main();
  forms.main();
  bug_checks.main();
  crud.main();
  offline.main();
}
