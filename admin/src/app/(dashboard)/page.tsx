import { AdminCards } from "../../components/admin-cards";

export default function DashboardPage() {
  return (
    <div>
      <h1>Dashboard</h1>
      <p>Overview metrics for users, events, and registrations.</p>
      <AdminCards />
    </div>
  );
}
