# Local validation evidence

`unit-tests.txt` and `demo-run.txt` contain actual local command output for the
routing-report update. Reproduce from the repository root:

```bash
python3 -m unittest discover -s tests -v
python3 automation/demo.py
```

The tests and demo use synthetic input. These files are evidence of code execution,
not router or cloud deployment. The missing-input CLI path was also checked:
exit code 1 and a written FAIL report. Python compilation passed.
