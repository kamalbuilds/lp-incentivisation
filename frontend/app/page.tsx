import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Progress } from "@/components/ui/progress"
import { PlusIcon, MinusIcon, LockIcon, UnlockIcon } from "lucide-react"

export default function LPIncentivisationApp() {
  return (
    <div className="container mx-auto p-4">
      <h1 className="text-3xl font-bold mb-6">LP Incentivisation Dashboard</h1>
      <Tabs defaultValue="add-liquidity" className="w-full">
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="add-liquidity">Add Liquidity</TabsTrigger>
          <TabsTrigger value="remove-liquidity">Remove Liquidity</TabsTrigger>
          <TabsTrigger value="rewards">Rewards</TabsTrigger>
          <TabsTrigger value="stats">Stats</TabsTrigger>
        </TabsList>
        <TabsContent value="add-liquidity">
          <AddLiquidityCard />
        </TabsContent>
        <TabsContent value="remove-liquidity">
          <RemoveLiquidityCard />
        </TabsContent>
        <TabsContent value="rewards">
          <RewardsCard />
        </TabsContent>
        <TabsContent value="stats">
          <StatsCard />
        </TabsContent>
      </Tabs>
    </div>
  )
}

function AddLiquidityCard() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Add Liquidity</CardTitle>
        <CardDescription>Provide liquidity to earn rewards</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="amount">Amount</Label>
            <Input id="amount" placeholder="Enter amount" type="number" />
          </div>
          <div className="space-y-2">
            <Label htmlFor="lockup">Lockup Period (days)</Label>
            <Input id="lockup" placeholder="Enter lockup period" type="number" />
          </div>
          <Button className="w-full">
            <PlusIcon className="mr-2 h-4 w-4" /> Add Liquidity
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

function RemoveLiquidityCard() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Remove Liquidity</CardTitle>
        <CardDescription>Withdraw your liquidity</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="remove-amount">Amount to Remove</Label>
            <Input id="remove-amount" placeholder="Enter amount" type="number" />
          </div>
          <Button className="w-full" variant="destructive">
            <MinusIcon className="mr-2 h-4 w-4" /> Remove Liquidity
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

function RewardsCard() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Your Rewards</CardTitle>
        <CardDescription>View and claim your earned rewards</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          <div className="flex justify-between items-center">
            <span>Total Rewards:</span>
            <span className="font-bold">1000 CAKE</span>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span>Time-Based Rewards:</span>
              <span>400 CAKE</span>
            </div>
            <div className="flex justify-between text-sm">
              <span>Amount-Based Rewards:</span>
              <span>300 CAKE</span>
            </div>
            <div className="flex justify-between text-sm">
              <span>Milestone Rewards:</span>
              <span>200 CAKE</span>
            </div>
            <div className="flex justify-between text-sm">
              <span>Utility-Based Rewards:</span>
              <span>100 CAKE</span>
            </div>
          </div>
          <Button className="w-full">Claim Rewards</Button>
        </div>
      </CardContent>
    </Card>
  )
}

function StatsCard() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Your Stats</CardTitle>
        <CardDescription>View your liquidity provision statistics</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          <div className="space-y-2">
            <div className="flex justify-between">
              <span>Total Liquidity Provided:</span>
              <span className="font-bold">10,000 CAKE</span>
            </div>
            <div className="flex justify-between">
              <span>Current Lockup Period:</span>
              <span className="font-bold">30 days</span>
            </div>
            <div className="flex items-center space-x-2">
              <span>Lockup Progress:</span>
              <Progress value={33} className="flex-grow" />
              <span>33%</span>
            </div>
          </div>
          <div className="space-y-2">
            <h4 className="font-semibold">Milestones</h4>
            <div className="grid grid-cols-3 gap-2">
              <Button variant="outline" size="sm">
                <LockIcon className="mr-2 h-4 w-4" /> 7 Days
              </Button>
              <Button variant="outline" size="sm">
                <UnlockIcon className="mr-2 h-4 w-4" /> 30 Days
              </Button>
              <Button variant="outline" size="sm" disabled>
                <LockIcon className="mr-2 h-4 w-4" /> 90 Days
              </Button>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}