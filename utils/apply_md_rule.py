"""Script to fix markdown table alignment for MD060 rule."""

import re
import sys


def calculate_column_widths(rows):
    """Calculate the maximum width for each column."""
    if not rows:
        return []
    num_cols = max(len(row) for row in rows)
    widths = [0] * num_cols
    for row in rows:
        for i, cell in enumerate(row):
            if i < num_cols:
                widths[i] = max(widths[i], len(cell))
    return widths


def parse_table_row(line):
    """Parse a markdown table row into cells."""
    # Remove leading and trailing pipes
    stripped = line.strip()
    if stripped.startswith('|'):
        stripped = stripped[1:]
    if stripped.endswith('|'):
        stripped = stripped[:-1]
    # Split by |
    cells = [cell.strip() for cell in stripped.split('|')]
    return cells


def is_separator_row(cells):
    """Check if the row is a separator row (contains only dashes, colons, or spaces)."""
    for cell in cells:
        clean = cell.strip()
        if clean and not re.match(r'^:?-+:?$', clean):
            return False
    return True


def format_table_row(cells, widths, is_separator=False):
    """Format a table row with aligned columns."""
    formatted_cells = []
    for i, cell in enumerate(cells):
        if i < len(widths):
            width = widths[i]
            if is_separator:
                # Handle alignment markers
                left_colon = cell.strip().startswith(':')
                right_colon = cell.strip().endswith(':')
                dashes = '-' * (width - (1 if left_colon else 0) -
                                (1 if right_colon else 0))
                formatted = (':', dashes, ':') if left_colon and right_colon else \
                    (':', dashes, '') if left_colon else \
                    ('', dashes, ':') if right_colon else \
                    ('', '-' * width, '')
                formatted_cells.append(''.join(formatted))
            else:
                formatted_cells.append(cell.ljust(width))
        else:
            formatted_cells.append(cell)
    return '| ' + ' | '.join(formatted_cells) + ' |'


def fix_table(lines):
    """Fix table alignment in a group of lines."""
    if len(lines) < 2:
        return lines

    # Parse all rows
    rows = [parse_table_row(line) for line in lines]

    # Calculate column widths
    widths = calculate_column_widths(rows)

    # Format each row
    result = []
    for cells in rows:
        is_sep = is_separator_row(cells)
        result.append(format_table_row(cells, widths, is_sep))

    return result


def process_file(file_path):
    """Process a markdown file and fix table alignment."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    lines = content.split('\n')
    result = []
    i = 0

    while i < len(lines):
        line = lines[i]

        # Check if this is the start of a table
        if line.strip().startswith('|') and '|' in line[1:]:
            # Collect all table lines
            table_lines = [line]
            j = i + 1
            while j < len(lines) and lines[j].strip().startswith('|') and '|' in lines[j][1:]:
                table_lines.append(lines[j])
                j += 1

            # Fix table alignment
            if len(table_lines) >= 2:
                fixed_lines = fix_table(table_lines)
                result.extend(fixed_lines)
            else:
                result.extend(table_lines)

            i = j
        else:
            result.append(line)
            i += 1

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(result))

    print(f"Fixed: {file_path}")


if __name__ == '__main__':
    for filepath in sys.argv[1:]:
        process_file(filepath)
