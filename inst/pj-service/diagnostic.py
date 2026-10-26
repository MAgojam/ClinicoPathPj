# Calcoli diagnostici delegati dal modulo ospite al servizio Pj.
import json
import math
import uuid

MEASUREMENT = 'marker'
REFERENCE = 'reference'
POSITIVE_LEVEL = CONFIG['positive']

if not d3_script:
    raise RuntimeError('The bundled D3 library is unavailable. Update or reinstall Pj.')

rows = []
excluded = 0
missing = [key for key in (MEASUREMENT, REFERENCE) if key not in data]
if missing:
    raise ValueError('The caller did not provide these columns: ' + ', '.join(missing) + '.')
if len(data[MEASUREMENT]) != len(data[REFERENCE]):
    raise ValueError('The selected columns must have the same number of rows.')
levels = set()
for index, (value, reference) in enumerate(zip(data[MEASUREMENT], data[REFERENCE])):
    if value is None or reference is None or reference == '':
        excluded += 1
        continue
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f'Row {index + 1}: the measurement must be numeric.')
    if not math.isfinite(value) or (isinstance(reference, float) and not math.isfinite(reference)):
        excluded += 1
        continue
    reference = str(reference)
    levels.add(reference)
    rows.append(dict(row=index + 1, value=float(value), positive=reference == POSITIVE_LEVEL))
if len(levels) != 2 or POSITIVE_LEVEL not in levels:
    raise ValueError('The complete rows must contain two reference levels, including POSITIVE_LEVEL.')
negative_level = next(level for level in levels if level != POSITIVE_LEVEL)
source = 'Selected dataset columns'

if len(rows) > 5000:
    raise ValueError('This SVG teaching example supports at most 5,000 complete rows.')
if not rows or not any(row['positive'] for row in rows) or all(row['positive'] for row in rows):
    raise ValueError('Both positive and negative reference observations are required.')


def classify(cutoff):
    counts = dict(tp=0, fp=0, fn=0, tn=0)
    for row in rows:
        predicted = row['value'] >= cutoff if CONFIG['direction'] == 'high' else row['value'] <= cutoff
        counts['tp' if predicted and row['positive'] else
               'fp' if predicted else 'fn' if row['positive'] else 'tn'] += 1
    return counts


# Valuta le soglie distinte, mantenendo uniti i valori uguali e includendo tutti i negativi.
ordered = sorted(rows, key=lambda row: row['value'])
above = math.nextafter(ordered[-1]['value'], math.inf)
below = math.nextafter(ordered[0]['value'], -math.inf)
if not all(math.isfinite(value) for value in (above, below)):
    raise ValueError('Measurements are too extreme for this teaching plot.')
counts = dict(tp=sum(row['positive'] for row in rows), fp=sum(not row['positive'] for row in rows), fn=0, tn=0)
candidates = []
index = 0
while index < len(ordered):
    value = ordered[index]['value']
    candidates.append(dict(cutoff=value, **counts))
    while index < len(ordered) and ordered[index]['value'] == value:
        positive = ordered[index]['positive']
        counts['tp' if positive else 'fp'] -= 1
        counts['fn' if positive else 'tn'] += 1
        index += 1
candidates.append(dict(cutoff=above, **counts))
# La direzione opposta comprende una soglia sotto il minimo.
le_counts = dict(tp=0, fp=0, fn=sum(row['positive'] for row in rows), tn=sum(not row['positive'] for row in rows))
le_candidates = [dict(cutoff=below, **le_counts)]
index = 0
while index < len(ordered):
    value = ordered[index]['value']
    while index < len(ordered) and ordered[index]['value'] == value:
        positive = ordered[index]['positive']
        le_counts['tp' if positive else 'fp'] += 1
        le_counts['fn' if positive else 'tn'] -= 1
        index += 1
    le_candidates.append(dict(cutoff=value, **le_counts))


def roc_curve(boundaries):
    positives = sum(row['positive'] for row in rows)
    negatives = len(rows) - positives
    points = [dict(item, tpr=item['tp'] / positives, fpr=item['fp'] / negatives) for item in boundaries]
    points.sort(key=lambda point: (point['fpr'], point['tpr']))
    auc = sum((right['fpr'] - left['fpr']) * (right['tpr'] + left['tpr']) / 2
              for left, right in zip(points, points[1:]))
    return dict(points=points, auc=auc)


curves = dict(ge=roc_curve(candidates), le=roc_curve(le_candidates))
direction = 'ge' if CONFIG['direction'] == 'high' else 'le'
boundaries = candidates if direction == 'ge' else le_candidates
def objective(item):
    if CONFIG['criterion'] == 'youden':
        return -(item['tp'] / (item['tp'] + item['fn']) - item['fp'] / (item['fp'] + item['tn']))
    return item['fp'] + item['fn']
best_value = min(map(objective, boundaries))
tied = [item for item in boundaries if math.isclose(objective(item), best_value, rel_tol=0, abs_tol=1e-12)]
best = min(tied, key=lambda item: item['cutoff'])
tie_count = len(tied)
entered = CONFIG['cutoff'].strip()
initial = float(entered) if entered else best['cutoff']
if isinstance(initial, bool) or not isinstance(initial, (int, float)) or not math.isfinite(initial):
    raise ValueError('The applied cutoff must be a finite number, or blank for automatic.')

payload = json.dumps(dict(rows=rows, initial=initial, automatic=best['cutoff'],
                          curves=curves,
                          expected=classify(initial), ties=tie_count, excluded=excluded,
                          positive=POSITIVE_LEVEL, negative=negative_level,
                          measurement=CONFIG['marker_label'], source='Dataset supplied by the calling R6 analysis', direction=direction, criterion=CONFIG['criterion'], manual=bool(entered)), ensure_ascii=False, allow_nan=False)
for character, escaped in (('&', '\\u0026'), ('<', '\\u003c'), ('>', '\\u003e'),
                           ('\u2028', '\\u2028'), ('\u2029', '\\u2029')):
    payload = payload.replace(character, escaped)
root_id = CONFIG.get('root_id') or 'mzpj_cutoff_' + uuid.uuid4().hex


from scipy.stats import binomtest
counts = classify(initial)
mzpjShowTable([dict(Classification=label, Count=counts[key]) for label, key in
    [('True positive', 'tp'), ('False positive', 'fp'), ('False negative', 'fn'), ('True negative', 'tn')]], name='counts')
tp, fp, fn, tn = (counts[key] for key in ('tp', 'fp', 'fn', 'tn'))
metrics = []
for label, numerator, denominator in [('Sensitivity', tp, tp + fn), ('Specificity', tn, tn + fp),
    ('Positive predictive value', tp, tp + fp), ('Negative predictive value', tn, tn + fn),
    ('Accuracy', tp + tn, len(rows))]:
    ci = binomtest(numerator, denominator).proportion_ci(method='exact') if denominator else None
    metrics.append(dict(Metric=label, Estimate=numerator / denominator if denominator else None,
                        Lower=ci.low if ci else None, Upper=ci.high if ci else None))
mzpjShowTable(metrics, name='metrics')
mzpjShowText('Applied cutoff: ' + repr(initial) + '; N = ' + str(len(rows)) +
    '; excluded = ' + str(excluded) + '; AUC = ' + format(curves[direction]['auc'], '.4f') +
    '; automatic cutoff = ' + repr(best['cutoff']) + '; tied optima = ' + str(tie_count), name='summary')
mzpjShowHtml(d3_script + TEMPLATE.replace('__ROOT__', root_id).replace('__PAYLOAD__', payload), name='explorer')
