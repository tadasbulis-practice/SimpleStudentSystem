<?php
declare(strict_types=1);

defined('APP_ROOT') || exit('No direct access.');

/**
 * All SQL for students. The statements use only standard SQL, so the same code works
 * on MySQL/MariaDB and on SQL Server. Table and column names match the table that
 * the .NET API (EF Core) creates – both APIs can share one database.
 */
final class StudentRepository
{
    private const COLUMNS = 'Id, FirstName, LastName, Email, StudyProgram, EnrollmentYear';

    public function __construct(private readonly PDO $db)
    {
    }

    /** @return array<int, array> */
    public function all(): array
    {
        $rows = $this->db->query('SELECT ' . self::COLUMNS . ' FROM Students ORDER BY Id')->fetchAll();
        return array_map([self::class, 'toApi'], $rows);
    }

    public function find(int $id): ?array
    {
        $stmt = $this->db->prepare('SELECT ' . self::COLUMNS . ' FROM Students WHERE Id = ?');
        $stmt->execute([$id]);
        $row = $stmt->fetch();
        return $row ? self::toApi($row) : null;
    }

    public function create(array $s): array
    {
        $stmt = $this->db->prepare(
            'INSERT INTO Students (FirstName, LastName, Email, StudyProgram, EnrollmentYear) VALUES (?, ?, ?, ?, ?)');
        $stmt->execute(self::values($s));
        return $this->find((int)$this->db->lastInsertId());
    }

    public function update(int $id, array $s): ?array
    {
        if ($this->find($id) === null) {
            return null;
        }
        $stmt = $this->db->prepare(
            'UPDATE Students SET FirstName = ?, LastName = ?, Email = ?, StudyProgram = ?, EnrollmentYear = ? WHERE Id = ?');
        $stmt->execute([...self::values($s), $id]);
        return $this->find($id);
    }

    public function delete(int $id): bool
    {
        $stmt = $this->db->prepare('DELETE FROM Students WHERE Id = ?');
        $stmt->execute([$id]);
        return $stmt->rowCount() > 0;
    }

    /** Database row (PascalCase columns) → API JSON (camelCase, correct types). */
    private static function toApi(array $row): array
    {
        return [
            'id'             => (int)$row['Id'],
            'firstName'      => (string)$row['FirstName'],
            'lastName'       => (string)$row['LastName'],
            'email'          => (string)$row['Email'],
            'studyProgram'   => (string)$row['StudyProgram'],
            'enrollmentYear' => (int)$row['EnrollmentYear'],
        ];
    }

    private static function values(array $s): array
    {
        return [$s['firstName'], $s['lastName'], $s['email'], $s['studyProgram'], (int)$s['enrollmentYear']];
    }
}
